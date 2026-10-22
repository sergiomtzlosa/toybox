#import <Cocoa/Cocoa.h>

#import "AppDelegate.h"

static ToyboxAppDelegate *gApplicationDelegate = nil;

int main(int argc, const char *argv[])
{
    (void)argc;
    (void)argv;
    @autoreleasepool {
        NSApplication *application = [NSApplication sharedApplication];
        gApplicationDelegate = [[ToyboxAppDelegate alloc] init];
        application.delegate = gApplicationDelegate;
        [application setActivationPolicy:NSApplicationActivationPolicyRegular];
        [application run];
    }
    return 0;
}
