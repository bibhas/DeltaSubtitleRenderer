// SubtitleRenderer.mm
// 2017 Bibhas Acharya <mail@bibhas.com>

#include <atomic>
#include <iostream>
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
  }
  return self;
}

- (void)setSubTitle:(NSString *)aSubtitleString from:(CMTime)startTime to:(CMTime)endTime {
  assert(isRendering.load() == false && "A render is in progress! Cannot add subtitles now...");
  std::cout << "Got subtitle : " << [aSubtitleString UTF8String] << " from : " << [NSStringFromCMTime(startTime) UTF8String] << " to : " << [NSStringFromCMTime(endTime) UTF8String] << std::endl; 
}

- (void)renderToMP4AtPath:(NSURL *)aFileURL {
  assert(isRendering.load() == false && "Another render is already in progress!");
  // Inform the delegate that we have started the render process
  if (delegate && [delegate respondsToSelector:@selector(subtitleRendererDidStartRendering:)]) {
    dispatch_async(dispatch_get_main_queue(), [self] {
      [delegate subtitleRendererDidStartRendering:self];
    });
  }
  // Setup the renderer innards

}

- (void)dealloc {
  if (inputFileURL != nil) {
    [inputFileURL release];
  }
  [super dealloc];
}

@end
