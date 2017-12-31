// SubtitleRenderer.mm
// 2017 Bibhas Acharya <mail@bibhas.com>

#include <atomic>
#include <memory>
#include <iostream>
#include <AVFoundation/AVFoundation.h>
#include "utils/cmtime.h"
#include "utils/compute.h"
#include "utils/gcd_timer.h"
#include "TextRenderer.h"
#include "SubtitleRenderer.h"

// SubtitleContext

@interface SubtitleContext : NSObject
- (id)initWithText:(NSString *)aTextString from:(CMTime)aStartTime to:(CMTime)aEndTime imageRepr:(CIImage *)aImage;
- (BOOL)relevantAtCompositionTime:(CMTime)aTime;
- (CIImage *)imageRepresentation;
@end

// SubtitleRenderer

@implementation SubtitleRenderer {
  id<SubtitleRendererDelegate> delegate;
  std::atomic<bool> isRendering;
  NSURL *inputFileURL;
  struct {
    AVAsset *asset;
    AVMutableVideoComposition *mutableFilteredComposition;
    AVAssetExportSession *exportSession;
    TextRenderer *textRenderer;
    std::unique_ptr<gcd_timer_t> progressTimer;
  } renderer;
  NSMutableArray *subtitleContexts;
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
      [resp setBackgroundColor:[NSColor colorWithWhite:0.0 alpha:0.8]];
      [resp setForegroundColor:[NSColor colorWithWhite:1.0 alpha:1.0]];
      [resp setFont:[NSFont fontWithName:@"Menlo" size:40.0]];
      return resp;
    });
    renderer.progressTimer = std::make_unique<gcd_timer_t>(0.5 * NSEC_PER_SEC, dispatch_get_main_queue(), [self] {
      if (renderer.exportSession) {
        if (delegate && [delegate respondsToSelector:@selector(subtitleRenderer:didRenderWithProgress:)]) {
          [delegate subtitleRenderer:self didRenderWithProgress:renderer.exportSession.progress];
        }
      }
    });
    subtitleContexts = [[NSMutableArray alloc] init];
  }
  return self;
}

- (void)setSubTitle:(NSString *)aSubtitleString from:(CMTime)aStartTime to:(CMTime)aEndTime {
  assert(isRendering.load() == false && "A render is in progress! Cannot add subtitles now...");
  std::cout << "Got subtitle : " << [aSubtitleString UTF8String] << " from : " << [NSStringFromCMTime(aStartTime) UTF8String] << " to : " << [NSStringFromCMTime(aEndTime) UTF8String] << std::endl; 
  // Render a CIImage with TextRenderer and put it in a cache
  AVAssetTrack *videoTrack = COMPUTE({
    assert([[renderer.asset tracksWithMediaType:AVMediaTypeVideo] count] > 0 && "Asset contains no video!");
    return [[renderer.asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
  });
  CMTime startTime = CMTimeConvertScale(aStartTime, [videoTrack naturalTimeScale], kCMTimeRoundingMethod_RoundHalfAwayFromZero);
  CMTime endTime = CMTimeConvertScale(aEndTime, [videoTrack naturalTimeScale], kCMTimeRoundingMethod_RoundHalfAwayFromZero);
  NSString *sanitizedString = [[aSubtitleString componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] componentsJoinedByString:@" "];
  CIImage *textImage = [renderer.textRenderer renderImageForString:sanitizedString];
  SubtitleContext *subtitleContext = [[SubtitleContext alloc] initWithText:aSubtitleString from:startTime to:endTime imageRepr:textImage];
  [textImage release];
  // Add to cache
  [subtitleContexts addObject:subtitleContext];
  [SubtitleContext release];
}

- (void)renderToMP4AtPath:(NSURL *)aFileURL {
  assert(isRendering.load() == false && "Another render is already in progress!");
  // Make sure the path is valid (a valid mp4 file), and if it is, and that it already exists, delete it
  NSError *error;
  [[NSFileManager defaultManager] removeItemAtPath:[aFileURL path] error:&error]; 
  // Inform the delegate that we have started the render process
  if (delegate && [delegate respondsToSelector:@selector(subtitleRendererDidStartRendering:)]) {
    dispatch_async(dispatch_get_main_queue(), [self] {
      [delegate subtitleRendererDidStartRendering:self];
    });
  }
  // Begin rendering
  isRendering.store(true);
  renderer.mutableFilteredComposition = [[AVMutableVideoComposition videoCompositionWithAsset:renderer.asset applyingCIFiltersWithHandler:[self](AVAsynchronousCIImageFilteringRequest *request) {
    // request.sourceImage, request.compositionTime, [request finishWithImage:... context:nil]
    for (SubtitleContext *context in subtitleContexts) {
      if ([context relevantAtCompositionTime:request.compositionTime]) {
        CIFilter *filter = [CIFilter filterWithName:@"CISourceOverCompositing"];
        [filter setDefaults];
        // Add background (the video image)
        CIImage *source = [request.sourceImage imageByClampingToExtent];
        [filter setValue:source forKey:kCIInputBackgroundImageKey];
        // Add text image on top of the video background
        CGAffineTransform transform = CGAffineTransformMakeTranslation(0, 0); // For now, just leave it as it is
        CIImage *textImage = [context imageRepresentation];
        CIImage *adjustedImage = [textImage imageByApplyingTransform:transform]; 
        [filter setValue:adjustedImage forKey:kCIInputImageKey]; 
        // Crop the video (useful later if we end up blurring the background or whatever, we'll see)
        CIImage *output = [filter.outputImage imageByCroppingToRect:request.sourceImage.extent];
        // Provide the filter output to the composition
        [request finishWithImage:output context:nil];
        // Since we've already applied this subtitle, stop the looking for relevant subtitles
        return;
      }
    }
    // If we found no subtitles for this frame, just pass the original video frame image
    [request finishWithImage:request.sourceImage context:nil];
  }] retain];
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
        renderer.progressTimer->pause();
        if (delegate && [delegate respondsToSelector:@selector(subtitleRendererDidFinishRendering:)]) {
          [delegate subtitleRendererDidFinishRendering:self];
        }
        break;
      }
      case AVAssetExportSessionStatusFailed: {
        std::cout << "AVAssetExportSession failed..." << std::endl;
        renderer.progressTimer->pause();
        if (delegate && [delegate respondsToSelector:@selector(subtitleRendererDidFinishRendering:)]) {
          [delegate subtitleRendererDidFinishRendering:self];
        }
        break;
      }
      case AVAssetExportSessionStatusCancelled: {
        std::cout << "AVAssetExportSession cancelled..." << std::endl;
        renderer.progressTimer->pause();
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
  // Start tracking progress
  renderer.progressTimer->resume();
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

// SubtitleContext

@implementation SubtitleContext {
  CMTime startTime;
  CMTime endTime;
  NSString *textRepr;
  CIImage *imageRepr;
}

- (id)initWithText:(NSString *)aTextString from:(CMTime)aStartTime to:(CMTime)aEndTime imageRepr:(CIImage *)aImage {
  self = [super init];
  if (self != nil) {
    startTime = aStartTime;
    endTime = aEndTime;
    textRepr = [aTextString retain];
    imageRepr = [aImage retain];
  }
  return self;
}

- (BOOL)relevantAtCompositionTime:(CMTime)currentTime {
  std::uint32_t startComparision = CMTimeCompare(startTime, currentTime);
  std::uint32_t endComparision = CMTimeCompare(endTime, currentTime);
  if (startComparision == 0 || endComparision == 0) {
    // If currentTime is either startTime or endTime, then YES
    return YES;
  }
  if (startComparision == -1 && endComparision == 1) {
    // If currentTime is greater than startTime but less than endTime, then YES
    return YES;
  }
  // NO for every other situation
  return NO;
}

- (CIImage *)imageRepresentation {
  return imageRepr;
}

- (void)dealloc {
  if (textRepr != nil) {
    [textRepr release];
  }
  if (imageRepr != nil) {
    [imageRepr release];
  }
  [super dealloc];
}

@end

