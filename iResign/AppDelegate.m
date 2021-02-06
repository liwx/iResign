//
//  AppDelegate.m
//  iResign
//
//  Created by liwx on 2021/2/5.
//

#import "AppDelegate.h"

@interface AppDelegate ()


@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)hasVisibleWindows {
    for (NSWindow *window in sender.windows) {
        if ([window isMemberOfClass:NSWindow.class]) {
            [window setIsVisible:YES];
            [window makeKeyAndOrderFront:self];
        }
    }
    return YES;
}

@end
