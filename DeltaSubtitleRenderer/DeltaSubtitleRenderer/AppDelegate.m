// AppDelegate.mm
// 2017 Bibhas Acharya <mail@bibhas.com>

#include <Availability.h>
#include "AppDelegate.h"

#ifndef MAC_OS_X_VERSION_10_12
// Since MAC_OS_X_VERSION_10_12 isn't defined, we're using a
// pre 10.12 SDK. That means we need to provide replacement
// for the newer enum values.
#define NSWindowStyleMaskTitled NSTitledWindowMask 
#define NSWindowStyleMaskClosable NSClosableWindowMask
#define NSWindowStyleMaskResizable NSResizableWindowMask
#endif

@interface AppDelegate (PRIVATE)
- (void)setupMenu;
@end

@implementation AppDelegate {
  NSWindow *window;
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
  NSView *contentView = [window contentView];
#pragma unused(contentView)
  // Show window and bring it to front
  [window makeKeyAndOrderFront:self];
  [self setupMenu];
}

- (void)dealloc {
  [window release];
  [super dealloc];
}

- (void)windowDidResize:(NSNotification *)notification {
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

@end
