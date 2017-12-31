// TextRenderer.mm
// 2017 Bibhas Acharya <mail@bibhas.com>

#include <CoreGraphics/CoreGraphics.h>
#include "utils/compute.h"
#include "TextRenderer.h"

@implementation TextRenderer {
  NSSize size;
  NSFont *font;
  NSColor *backgroundColor;
  NSColor *foregroundColor;
  CGContextRef bitmapContext;
}

- (id)initWithSize:(NSSize)aSize {
  self = [super init];
  if (self != nil) {
    size = aSize;
    font = [[NSFont fontWithName:@"Arial-BoldMT" size:49] retain];
    backgroundColor = [[NSColor colorWithWhite:0.0 alpha:0.5] retain];
    foregroundColor = [[NSColor colorWithWhite:1.0 alpha:1.0] retain];
    bitmapContext = COMPUTE(CGContextRef, {
      CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
      CGContextRef resp = CGBitmapContextCreate(NULL, aSize.width, aSize.height, 8, 0, colorSpace, kCGImageAlphaPremultipliedLast);
      CFRelease(colorSpace);
      assert(resp != NULL && "Could not create CGBitmapContextRef to render text into!");
      return resp;
    });
  }
  return self;
}

- (void)dealloc {
  if (font != nil) {
    [font release];
  }
  if (backgroundColor != nil) {
    [backgroundColor release];
  }
  if (bitmapContext != nil) {
    CGContextRelease(bitmapContext);
  }
  [super dealloc];
}

- (void)setFont:(NSFont *)aFont {
  assert(aFont != nil && "You passed an empty NSFont as the text font for TextRenderer!");
  if (font != nil) {
    [font release];
  }
  font = [aFont retain];
}

- (void)setForegroundColor:(NSColor *)aColor {
  assert(aColor != nil && "You passed an empty NSColor as foreground for TextRenderer!");
  if (foregroundColor != nil) {
    [foregroundColor release];
  } 
  foregroundColor = [aColor retain];
}

- (void)setBackgroundColor:(NSColor *)aColor {
  assert(aColor != nil && "You passed an empty NSColor as background for TextRenderer!");
  if (backgroundColor != nil) {
    [backgroundColor release];
  } 
  backgroundColor = [aColor retain];
}

- (CIImage *)renderImageForString:(NSString *)aText {
  CGContextClearRect(bitmapContext, CGRectMake(0, 0, size.width, size.height));
  // Draw text into CGBitmapContextRef
  [NSGraphicsContext saveGraphicsState];
  NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithCGContext:bitmapContext flipped:NO];
  [NSGraphicsContext setCurrentContext:context];
  {
    // Drawing code imported from PaintCode
    NSRect frame = NSMakeRect(0, 0, size.width, size.height);
    {
      //// Rectangle Drawing
      NSBezierPath* rectanglePath = [NSBezierPath bezierPathWithRect: NSMakeRect(NSMinX(frame), NSMinY(frame), frame.size.width, frame.size.height)];
      [backgroundColor setFill];
      [rectanglePath fill];
      //// Text Drawing
      NSRect textRect = NSMakeRect(NSMinX(frame), NSMinY(frame), frame.size.width, frame.size.height);
      {
        NSString* textContent = aText;
        NSMutableParagraphStyle* textStyle = [[[NSMutableParagraphStyle alloc] init] autorelease];
        textStyle.alignment = NSTextAlignmentCenter;
        NSDictionary* textFontAttributes = @{NSFontAttributeName:font, NSForegroundColorAttributeName:foregroundColor, NSParagraphStyleAttributeName: textStyle};
        // Draw Text
        CGFloat textTextHeight = [textContent boundingRectWithSize: textRect.size options: NSStringDrawingUsesLineFragmentOrigin attributes: textFontAttributes].size.height;
        NSRect textTextRect = NSMakeRect(NSMinX(textRect), NSMinY(textRect) + (textRect.size.height - textTextHeight) / 2, textRect.size.width, textTextHeight);
        [NSGraphicsContext saveGraphicsState];
        NSRectClip(textRect);
        [textContent drawInRect: NSOffsetRect(textTextRect, 0, 0) withAttributes: textFontAttributes];
        [NSGraphicsContext restoreGraphicsState];
      }
    }
  }
  [NSGraphicsContext restoreGraphicsState];
  // Produce CGImage and then CIImage from the context
  CGImageRef image = CGBitmapContextCreateImage(bitmapContext);
  CIImage *resp = [[CIImage alloc] initWithCGImage:image];
  CGImageRelease(image);
  return resp;
}

@end
