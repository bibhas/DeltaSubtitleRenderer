// SubtitleRenderer.mm
// 2017 Bibhas Acharya <mail@bibhas.com>

#include "SubtitleRenderer.h"

@interface SubtitleRenderer (PRIVATE)
@end

@implementation SubtitleRenderer {

}

- (id)initWithMP4AtPath:(NSURL *)aFileURL delegate:(id<SubtitleRendererDelegate>)aDelegate {
  self = [super init];
  if (self != nil) {

  }
  return self;
}

- (void)setSubTitle:(NSString *)aSubtitleString from:(CMTime)startTime to:(CMTime)endTime {

}

- (void)beginRendering {

}

@end
