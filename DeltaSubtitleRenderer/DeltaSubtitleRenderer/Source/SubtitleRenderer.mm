// SubtitleRenderer.mm
// 2017 Bibhas Acharya <mail@bibhas.com>

#include <atomic>
#include <iostream>
#include <AVFoundation/AVFoundation.h>
#include "utils/cmtime.h"
#include "utils/compute.h"
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
  }
  return self;
}

- (void)setSubTitle:(NSString *)aSubtitleString from:(CMTime)startTime to:(CMTime)endTime {
  assert(isRendering.load() == false && "A render is in progress! Cannot add subtitles now...");
  std::cout << "Got subtitle : " << [aSubtitleString UTF8String] << " from : " << [NSStringFromCMTime(startTime) UTF8String] << " to : " << [NSStringFromCMTime(endTime) UTF8String] << std::endl; 
  // Render a CGImage with the caption and store it for now
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
    CIFilter *filter = [CIFilter filterWithName:@"CIGaussianBlur"];
    // Clamp to avoid blurring transparent pixels at the image edges
    CIImage *source = [request.sourceImage imageByClampingToExtent];
    [filter setValue:source forKey:kCIInputImageKey];
    // Vary filter parameters based on video timing
    Float64 seconds = CMTimeGetSeconds(request.compositionTime);
    [filter setValue:[NSNumber numberWithFloat:3.0] forKey:kCIInputRadiusKey];
    // Crop the blurred output to the bounds of the original image
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
    }
  }];
}

- (void)dealloc {
  if (inputFileURL != nil) {
    [inputFileURL release];
  }
  [super dealloc];
}

@end
