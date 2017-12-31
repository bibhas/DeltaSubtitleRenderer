// AppDelegate.mm
// 2017 Bibhas Acharya <mail@bibhas.com>

#include <iostream>
#include <Availability.h>
#include <SubRipForCocoa/SubRip.h>
#include <MBDropZone/MBDropZone.h>
#include "utils/compute.h"
#include "FlippedView.h"
#include "AppDelegate.h"

#ifndef MAC_OS_X_VERSION_10_12
// Since MAC_OS_X_VERSION_10_12 isn't defined, we're using a
// pre 10.12 SDK. That means we need to provide replacement
// for the newer enum values.
#define NSWindowStyleMaskTitled NSTitledWindowMask 
#define NSWindowStyleMaskClosable NSClosableWindowMask
#define NSWindowStyleMaskResizable NSResizableWindowMask
#endif

@interface AppDelegate (PRIVATE) <MBDropZoneDelegate, SubtitleRendererDelegate>
- (void)setupMenu;
@end

@implementation AppDelegate {
  NSWindow *window;
  FlippedView *contentView;
  MBDropZone *mp4DropZone;
  MBDropZone *srtDropZone;
  NSProgressIndicator *progressIndicator;
  NSButton *startButton;
  SubtitleRenderer *subtitleRenderer; 
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {       
  NSRect windowRect = NSMakeRect(0, 0, STARTUP_WINDOW_WIDTH, STARTUP_WINDOW_HEIGHT);
  window = [[NSWindow alloc] initWithContentRect:windowRect
    styleMask: NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
    backing: NSBackingStoreBuffered 
    defer:NO];
  [window setShowsResizeIndicator:YES];
  [window setPreferredBackingLocation:NSWindowBackingLocationVideoMemory];                                
  [window setTitle:@"Delta Subtitle Renderer : Demo"];
  [window setDelegate:self];
  [window center];
  // Setup contentview
  contentView = [[FlippedView alloc] initWithFrame:[[window contentView] bounds]];
  [window setContentView:contentView];
  std::uint32_t zoneWidth = 235;
  std::uint32_t zoneHeight = 200;
  // Add mp4 drop zone
  mp4DropZone = COMPUTE(MBDropZone *, {
    MBDropZone *resp = [[MBDropZone alloc] initWithFrame:NSMakeRect(10, 15, zoneWidth, zoneHeight)];
    [resp setText:@"Drop Video File"];
    [resp setFileType:@".mp4"];
    [resp setDelegate:self];
    return resp;
  });
  [contentView addSubview:mp4DropZone];
  // Add subtitles drop zone
  srtDropZone = COMPUTE(MBDropZone *, {
    MBDropZone *resp = [[MBDropZone alloc] initWithFrame:NSMakeRect(zoneWidth + 20, 15, zoneWidth, zoneHeight)];
    [resp setText:@"Drop Subtitles File"];
    [resp setFileType:@".srt"];
    [resp setDelegate:self];
    return resp;
  });
  [contentView addSubview:srtDropZone];
  // Add progress indicator
  progressIndicator = COMPUTE(NSProgressIndicator *, {
    NSProgressIndicator *resp = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(15, zoneHeight + 10 + 15, STARTUP_WINDOW_WIDTH - 30, 28)];
    [resp setStyle:NSProgressIndicatorBarStyle];
    [resp setMinValue:0.0];
    [resp setMaxValue:1.0];
    [resp setIndeterminate:NO];
    [resp setAlphaValue:0.2];
    [resp setDoubleValue:0.0];
    return resp;
  });
  [contentView addSubview:progressIndicator];
  // Add start button
  startButton = COMPUTE(NSButton *, {
    NSButton *resp = [[NSButton alloc] initWithFrame:NSMakeRect(10, zoneHeight + 10 + 10 + 28 + 10, STARTUP_WINDOW_WIDTH - 20, 28)];
    [resp setTitle:@"Start Rendering"];
    [resp setBezelStyle:NSRoundedBezelStyle];
    [resp setTarget:self];
    [resp setEnabled:NO];
    [resp setAction:@selector(startButtonClicked:)];
    return resp;
  });
  [contentView addSubview:startButton];
  // Show window and bring it to front
  [window makeKeyAndOrderFront:self];
  [self setupMenu];
}

- (void)startButtonClicked:(id)sender {
  // Reset progress Indicator
  [[progressIndicator animator] setDoubleValue:0.0];
  [startButton setEnabled:NO];
  [startButton setTitle:@"Rendering, please wait"];
  [mp4DropZone setEnabled:NO];
  [srtDropZone setEnabled:NO];
  // Start rendering
  SubRip *ripper = [[SubRip alloc] initWithFile:[srtDropZone file]];
  // Prepare renderer
  if (subtitleRenderer != nil) {
    [subtitleRenderer release];
    subtitleRenderer = nil;
  }
  NSURL *mp4Path = [NSURL fileURLWithPath:[mp4DropZone file]];
  subtitleRenderer = [[SubtitleRenderer alloc] initWithMP4AtPath:mp4Path delegate:self];
  // Parse subtitles and feed them to the renderer
  std::uint32_t i = 0;
  for (;;) {
    SubRipItem *item = [ripper subRipItemAtIndex:i];
    if (item == nil) {
      break;
    }
    [subtitleRenderer setSubTitle:[item text] from:[item startTime] to:[item endTime]];
    i++;
  }
  std::cout << "Read " << i + 1 << " subtitles from srt file..." << std::endl;
  // Begin render
  NSString *renderPathString = COMPUTE({
    NSString *val = @"~/Desktop/render.out.mp4";
    return [[val stringByExpandingTildeInPath] stringByStandardizingPath];
  });
  NSURL *renderPath = [NSURL fileURLWithPath:renderPathString];
  std::cout << "Rendering to file at : " << [[renderPath absoluteString] UTF8String] << std::endl;
  [subtitleRenderer renderToMP4AtPath:renderPath];
}

- (void)dropZone:(MBDropZone*)dropZone receivedFile:(NSString*)file {
  // Update files
  if (dropZone == mp4DropZone) {
    std::cout << "Got mp4 : " << [[mp4DropZone file] UTF8String] << std::endl;
  }
  else if (dropZone == srtDropZone) {
    std::cout << "Got srt : " << [[srtDropZone file] UTF8String] << std::endl;
  }
  else {
    std::cerr << "Got something else..." << [file UTF8String] << std::endl;
  }
  // If either one of the drop zones got new file, we want to rest the progress bar
  [[progressIndicator animator] setDoubleValue:0.0];
  [startButton setTitle:@"Start Rendering"];
  [startButton setEnabled:YES];
  // If we have both files, enable the start button
  if ([mp4DropZone file] != nil && [srtDropZone file] != nil) {
    [startButton setEnabled:YES];
    [progressIndicator setAlphaValue:1.0];
  }
}

- (void)dealloc {
  [window release];
  if (subtitleRenderer != nil) {
    [subtitleRenderer release];
  }
  [super dealloc];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
  return NSTerminateNow;
}

- (BOOL)windowShouldClose:(id)sender {       
  [NSApp terminate:self];
  return YES;
}

- (void)setupMenu {
  // Create menu bar
  id menubar = [[NSMenu new] autorelease];
  id appMenuItem = [[NSMenuItem new] autorelease];
  [menubar addItem:appMenuItem];
  // Setup menu items
  id appMenu = [[NSMenu new] autorelease];
  id appName = [[NSProcessInfo processInfo] processName];
  id quitTitle = [@"Quit " stringByAppendingString:appName];
  id quitMenuItem = [[[NSMenuItem alloc] initWithTitle:quitTitle action:@selector(terminate:) keyEquivalent:@"q"] autorelease];
  [appMenu addItem:quitMenuItem];
  [appMenuItem setSubmenu:appMenu];
  [NSApp setMainMenu:menubar];
}

// SubtitleRendererDelegate methods

- (void)subtitleRendererDidStartRendering:(SubtitleRenderer *)aRenderer {
  [progressIndicator setAlphaValue:1.0];
  [[progressIndicator animator] setDoubleValue:0.0];
}

- (void)subtitleRenderer:(SubtitleRenderer *)aRenderer didRenderWithProgress:(float)aProgressValue {
  [[progressIndicator animator] setDoubleValue:aProgressValue];
}

- (void)subtitleRendererDidFinishRendering:(SubtitleRenderer *)aRenderer {
  [mp4DropZone setEnabled:YES];
  [srtDropZone setEnabled:YES];
  [startButton setTitle:@"Re-render video"];
  [startButton setEnabled:YES];
}

@end
