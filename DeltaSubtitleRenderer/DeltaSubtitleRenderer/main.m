// main.mm
// 2017 Bibhas Acharya <mail@bibhas.com>

#include <Cocoa/Cocoa.h>
#include "AppDelegate.h"

int main(int argc, char **argv) {
  NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
  AppDelegate * delegate = [[AppDelegate alloc] init];
  NSApplication * application = [NSApplication sharedApplication];
  [application setDelegate:delegate];
  [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
  [NSApp activateIgnoringOtherApps:YES];
  [NSApp run];
  [pool drain];
  return 0;
}
