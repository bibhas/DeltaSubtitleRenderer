// TextRenderer.h
// 2017 Bibhas Acharya <mail@bibhas.com>

#pragma once

#include <CoreImage/CoreImage.h>
#include <Cocoa/Cocoa.h>

@interface TextRenderer : NSObject
- (id)initWithSize:(NSSize)aSize;
- (void)setFont:(NSFont *)aFont;
- (void)setForegroundColor:(NSColor *)aColor;
- (void)setBackgroundColor:(NSColor *)aColor;
- (CIImage *)renderImageForString:(NSString *)aText;
@end

