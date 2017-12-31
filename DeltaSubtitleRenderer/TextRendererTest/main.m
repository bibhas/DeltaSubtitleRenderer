// main.mm
// 2017 Bibhas Acharya <mail@bibhas.com>

#import <Foundation/Foundation.h>
#include "TextRenderer.h"

BOOL CGImageWriteToFile(CGImageRef image, NSString *path) {
    CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:path];
    CGImageDestinationRef destination = CGImageDestinationCreateWithURL(url, kUTTypePNG, 1, NULL);
    if (!destination) {
        NSLog(@"Failed to create CGImageDestination for %@", path);
        return NO;
    }

    CGImageDestinationAddImage(destination, image, nil);

    if (!CGImageDestinationFinalize(destination)) {
        NSLog(@"Failed to write image to %@", path);
        CFRelease(destination);
        return NO;
    }

    CFRelease(destination);
    return YES;
}

int main(int argc, const char * argv[]) {
  TextRenderer *textRenderer = [[TextRenderer alloc] initWithSize:NSMakeSize(1280, 70)];
  [textRenderer setBackgroundColor:[NSColor colorWithWhite:0.0 alpha:0.5]];
  [textRenderer setForegroundColor:[NSColor colorWithWhite:1.0 alpha:1.0]];
  [textRenderer setFont:[NSFont systemFontOfSize:40.0f]];
  CIImage *textImage = [textRenderer renderImageForString:@"Hello Bibhas!"];
  CGImageRef textImageRef = textImage.CGImage;
  // Write image
  CGImageWriteToFile(textImageRef, @"/Users/bibhas/Desktop/output.png");
}
