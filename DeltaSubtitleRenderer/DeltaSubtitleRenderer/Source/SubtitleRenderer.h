// SubtitleRenderer.h
// 2017 Bibhas Acharya <mail@bibhas.com>

#pragma once

#include <Cocoa/Cocoa.h>
#include <CoreMedia/CMTime.h>

@class SubtitleRenderer;

@protocol SubtitleRendererDelegate <NSObject>
- (void)subtitleRendererDidStartRendering:(SubtitleRenderer *)aRenderer;
- (void)subtitleRenderer:(SubtitleRenderer *)aRenderer didRenderWithProgress:(float)aProgressValue;
- (void)subtitleRendererDidFinishRendering:(SubtitleRenderer *)aRenderer;
@end

@interface SubtitleRenderer : NSObject
- (id)initWithMP4AtPath:(NSURL *)aFileURL delegate:(id<SubtitleRendererDelegate>)aDelegate;
- (void)setSubTitle:(NSString *)aSubtitleString from:(CMTime)startTime to:(CMTime)endTime;
- (void)renderToMP4AtPath:(NSURL *)aFileURL;
@end
