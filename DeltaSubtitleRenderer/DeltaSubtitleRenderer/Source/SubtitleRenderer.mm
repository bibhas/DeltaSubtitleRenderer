// SubtitleRenderer.mm
// 2017 Bibhas Acharya <mail@bibhas.com>

#include <atomic>
#include <iostream>
#include "utils/cmtime.h"
#include "SubtitleRenderer.h"

// SubtitleRenderer

@interface SubtitleRenderer (PRIVATE)
@end

@implementation SubtitleRenderer {
  id<SubtitleRendererDelegate> delegate;
  std::atomic<bool> isRendering;
}

- (id)initWithMP4AtPath:(NSURL *)aFileURL delegate:(id<SubtitleRendererDelegate>)aDelegate {
  self = [super init];
  if (self != nil) {
    delegate = aDelegate;
    isRendering.store(false);
  }
  return self;
}

- (void)setSubTitle:(NSString *)aSubtitleString from:(CMTime)startTime to:(CMTime)endTime {
  assert(isRendering.load() == false && "A render is in progress! Cannot add subtitles now...");
  std::cout << "Got subtitle : " << [aSubtitleString UTF8String] << " from : " << [NSStringFromCMTime(startTime) UTF8String] << " to : " << [NSStringFromCMTime(endTime) UTF8String] << std::endl; 
}

- (void)renderToMP4AtPath:(NSURL *)aFileURL {
  std::cout << "Began rendering..." << std::endl;
  assert(isRendering.load() == false && "Another render is already in progress!");
}

@end
