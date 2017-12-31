// SubtitleRenderer.mm
// 2017 Bibhas Acharya <mail@bibhas.com>

#include <atomic>
#include <iostream>
#include <AVFoundation/AVFoundation.h>
#include "utils/cmtime.h"
#include "utils/compute.h"
#include "TextRenderer.h"
#include "SubtitleRenderer.h"

// SubtitleRenderer

@interface SubtitleRenderer (PRIVATE)
@end

@implementation SubtitleRenderer {
  id<SubtitleRendererDelegate> delegate;
  std::atomic<bool> isRendering;
  NSURL *inputFileURL;
  struct {
    AVAsset *asset;
    AVMutableVideoComposition *mutableFilteredComposition;
    AVAssetExportSession *exportSession;
    TextRenderer *textRenderer;
  } renderer;
}

- (id)initWithMP4AtPath:(NSURL *)aFileURL delegate:(id<SubtitleRendererDelegate>)aDelegate {
  self = [super init];
  if (self != nil) {
    delegate = aDelegate;
    isRendering.store(false);
    inputFileURL = COMPUTE(NSURL *, {
      assert(aFileURL != nil && "Input MP4 cannot be nil!");
      return [aFileURL retain];
    });
    renderer.asset = [[AVAsset assetWithURL:aFileURL] retain];
    renderer.textRenderer = COMPUTE(TextRenderer *, {
      TextRenderer *resp = [[TextRenderer alloc] initWithSize:COMPUTE(NSSize, {
        AVAssetTrack *videoTrack = COMPUTE({
          assert([[renderer.asset tracksWithMediaType:AVMediaTypeVideo] count] > 0 && "Asset contains no video!");
          return [[renderer.asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
        });
        CGSize frameSize = [videoTrack naturalSize];
        return NSMakeSize(frameSize.width, roundf((70.0f / 720.0f) * frameSize.height));
      })];
      [resp setBackgroundColor:[NSColor colorWithWhite:0.0 alpha:0.5]];
      [resp setForegroundColor:[NSColor colorWithWhite:1.0 alpha:1.0]];
      [resp setFont:[NSFont systemFontOfSize:40.0f]];
      return resp;
    });
  }
  return self;
}

- (void)setSubTitle:(NSString *)aSubtitleString from:(CMTime)aStartTime to:(CMTime)aEndTime {
  assert(isRendering.load() == false && "A render is in progress! Cannot add subtitles now...");
  std::cout << "Got subtitle : " << [aSubtitleString UTF8String] << " from : " << [NSStringFromCMTime(aStartTime) UTF8String] << " to : " << [NSStringFromCMTime(aEndTime) UTF8String] << std::endl; 
  // Render a CIImage with TextRenderer and put it in a cache
  // TODO
  //CGTime startTime = CMTimeConvertScale(aStartTime, [videoTrack naturalTimeScale], kCMTimeRoundingMethod_RoundHalfAwayFromZero);
  // TODO
}

- (void)renderToMP4AtPath:(NSURL *)aFileURL {
  assert(isRendering.load() == false && "Another render is already in progress!");
  // Inform the delegate that we have started the render process
  if (delegate && [delegate respondsToSelector:@selector(subtitleRendererDidStartRendering:)]) {
    dispatch_async(dispatch_get_main_queue(), [self] {
      [delegate subtitleRendererDidStartRendering:self];
    });
  }
  // Begin rendering
  isRendering.store(true);
  renderer.mutableFilteredComposition = [AVMutableVideoComposition videoCompositionWithAsset:renderer.asset applyingCIFiltersWithHandler:[self](AVAsynchronousCIImageFilteringRequest *request) {
    // request.sourceImage, request.compositionTime, [request finishWithImage:... context:nil]
    CIFilter *filter = [CIFilter filterWithName:@"CISourceOverCompositing"];
    [filter setDefaults];
    // Add background (the video image)
    CIImage *source = [request.sourceImage imageByClampingToExtent];
    [filter setValue:source forKey:kCIInputImageKey];
    // Add text image on top of the video background
    CGAffineTransform transform = CGAffineTransformMakeTranslation(0, 100);
    CIImage *textImage = [renderer.textRenderer renderImageForString:@"Hello Bibhas!"];
    CIImage *adjustedImage = [textImage imageByApplyingTransform:transform]; 
    [filter setValue:adjustedImage forKey:kCIInputBackgroundImageKey]; 
    // Crop the video (useful later if we end up blurring the background or whatever, we'll see)
    CIImage *output = [filter.outputImage imageByCroppingToRect:request.sourceImage.extent];
    // Provide the filter output to the composition
    [request finishWithImage:output context:nil];
  }];
  renderer.exportSession = COMPUTE(AVAssetExportSession *, {
    AVAssetExportSession *resp = [[AVAssetExportSession alloc] initWithAsset:renderer.asset presetName:AVAssetExportPreset1280x720];
    resp.videoComposition = renderer.mutableFilteredComposition;
    resp.outputURL = aFileURL;
    resp.outputFileType = AVFileTypeMPEG4;
    return resp;
  });
  [renderer.exportSession exportAsynchronouslyWithCompletionHandler:[self] {
    switch (renderer.exportSession.status) {
      case AVAssetExportSessionStatusCompleted: {
        std::cout << "AVAssetExportSession completed..." << std::endl;
        break;
      }
      case AVAssetExportSessionStatusFailed: {
        std::cout << "AVAssetExportSession failed..." << std::endl;
        break;
      }
      case AVAssetExportSessionStatusCancelled: {
        std::cout << "AVAssetExportSession cancelled..." << std::endl;
        break;
      }
      case AVAssetExportSessionStatusUnknown: {
        break;
      }
      case AVAssetExportSessionStatusExporting: {
        break;
      }
      case AVAssetExportSessionStatusWaiting: {
        break;
      }
    }
  }];
}

- (void)dealloc {
  if (inputFileURL != nil) {
    [inputFileURL release];
  }
  if (renderer.exportSession != nil) {
    [renderer.exportSession cancelExport];
    [renderer.exportSession release];
  }
  if (renderer.mutableFilteredComposition != nil) {
    [renderer.mutableFilteredComposition release];
  }
  if (renderer.asset != nil) {
    [renderer.asset release];
  }
  [super dealloc];
}

@end
