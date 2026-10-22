#import "AppDelegate.h"

#import "MainWindowController.h"

@interface ToyboxAppDelegate ()
@property (nonatomic, strong) MainWindowController *windowController;
@end

@implementation ToyboxAppDelegate

- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
    (void)notification;
    [self buildMainMenu];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    (void)notification;
    self.windowController = [[MainWindowController alloc] init];
    [self.windowController showWindow:nil];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    (void)sender;
    return YES;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)hasVisibleWindows
{
    (void)sender;
    if (!hasVisibleWindows) {
        [self.windowController showWindow:nil];
    }
    return YES;
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    (void)notification;
    [self.windowController shutdown];
}

- (void)silenceAllSounds:(id)sender
{
    (void)sender;
    [self.windowController silenceAllSounds];
}

- (void)toggleRecording:(id)sender
{
    [self.windowController toggleRecording:sender];
}

- (void)revealRecordingsFolder:(id)sender
{
    [self.windowController revealRecordingsFolder:sender];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    if (menuItem.action == @selector(toggleRecording:)) {
        menuItem.title = self.windowController.isRecording ? @"Stop Recording" : @"Start Recording";
        return YES;
    }
    return YES;
}

- (void)showAboutPanel:(id)sender
{
    (void)sender;
    NSString *creditString = @"An Otamatone and a rubber chicken, drawn and synthesized entirely in code.\n"
                             @"Every sound is generated live with AVAudioEngine.";
    NSMutableParagraphStyle *creditsStyle = [[NSMutableParagraphStyle alloc] init];
    creditsStyle.alignment = NSTextAlignmentCenter;
    NSAttributedString *credits = [[NSAttributedString alloc] initWithString:creditString
                                                                  attributes:@{
        NSFontAttributeName: [NSFont systemFontOfSize:11.0],
        NSForegroundColorAttributeName: [NSColor secondaryLabelColor],
        NSParagraphStyleAttributeName: creditsStyle
    }];
    NSDictionary *options = @{
        NSAboutPanelOptionApplicationName: @"Toybox",
        NSAboutPanelOptionApplicationVersion: @"1.0",
        NSAboutPanelOptionVersion: @"Version 1.0",
        NSAboutPanelOptionCredits: credits
    };
    [NSApp orderFrontStandardAboutPanelWithOptions:options];
}

- (void)buildMainMenu
{
    NSMenu *mainMenu = [[NSMenu alloc] initWithTitle:@"Main Menu"];

    NSString *appName = @"Toybox";
    NSMenuItem *appItem = [[NSMenuItem alloc] initWithTitle:appName action:nil keyEquivalent:@""];
    [mainMenu addItem:appItem];
    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:appName];

    NSMenuItem *aboutItem = [[NSMenuItem alloc] initWithTitle:@"About Toybox"
                                                       action:@selector(showAboutPanel:)
                                                keyEquivalent:@""];
    aboutItem.target = self;
    [appMenu addItem:aboutItem];
    [appMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *hideItem = [[NSMenuItem alloc] initWithTitle:@"Hide Toybox"
                                                      action:@selector(hide:)
                                               keyEquivalent:@"h"];
    hideItem.target = nil;
    [appMenu addItem:hideItem];

    NSMenuItem *hideOthersItem = [[NSMenuItem alloc] initWithTitle:@"Hide Others"
                                                            action:@selector(hideOtherApplications:)
                                                     keyEquivalent:@"h"];
    hideOthersItem.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagOption;
    hideOthersItem.target = nil;
    [appMenu addItem:hideOthersItem];

    NSMenuItem *showAllItem = [[NSMenuItem alloc] initWithTitle:@"Show All"
                                                         action:@selector(unhideAllApplications:)
                                                  keyEquivalent:@""];
    showAllItem.target = nil;
    [appMenu addItem:showAllItem];
    [appMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit Toybox"
                                                      action:@selector(terminate:)
                                               keyEquivalent:@"q"];
    quitItem.target = NSApp;
    [appMenu addItem:quitItem];
    appItem.submenu = appMenu;

    NSMenuItem *performanceItem = [[NSMenuItem alloc] initWithTitle:@"Performance"
                                                               action:nil
                                                        keyEquivalent:@""];
    [mainMenu addItem:performanceItem];
    NSMenu *performanceMenu = [[NSMenu alloc] initWithTitle:@"Performance"];

    NSMenuItem *recordItem = [[NSMenuItem alloc] initWithTitle:@"Start Recording"
                                                         action:@selector(toggleRecording:)
                                                  keyEquivalent:@"r"];
    recordItem.target = self;
    [performanceMenu addItem:recordItem];

    NSMenuItem *revealRecordingsItem = [[NSMenuItem alloc] initWithTitle:@"Show Recordings Folder"
                                                                   action:@selector(revealRecordingsFolder:)
                                                            keyEquivalent:@""];
    revealRecordingsItem.target = self;
    [performanceMenu addItem:revealRecordingsItem];
    [performanceMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *stopSoundsItem = [[NSMenuItem alloc] initWithTitle:@"Silence All Sounds"
                                                             action:@selector(silenceAllSounds:)
                                                      keyEquivalent:@"."];
    stopSoundsItem.target = self;
    [performanceMenu addItem:stopSoundsItem];

    performanceItem.submenu = performanceMenu;

    NSMenuItem *windowItem = [[NSMenuItem alloc] initWithTitle:@"Window" action:nil keyEquivalent:@""];
    [mainMenu addItem:windowItem];
    NSMenu *windowMenu = [[NSMenu alloc] initWithTitle:@"Window"];

    NSMenuItem *minimizeItem = [[NSMenuItem alloc] initWithTitle:@"Minimize"
                                                          action:@selector(performMiniaturize:)
                                                   keyEquivalent:@"m"];
    minimizeItem.target = nil;
    [windowMenu addItem:minimizeItem];

    NSMenuItem *zoomItem = [[NSMenuItem alloc] initWithTitle:@"Zoom"
                                                      action:@selector(performZoom:)
                                               keyEquivalent:@""];
    zoomItem.target = nil;
    [windowMenu addItem:zoomItem];
    [windowMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *closeItem = [[NSMenuItem alloc] initWithTitle:@"Close"
                                                       action:@selector(performClose:)
                                                keyEquivalent:@"w"];
    closeItem.target = nil;
    [windowMenu addItem:closeItem];

    NSMenuItem *frontItem = [[NSMenuItem alloc] initWithTitle:@"Bring All to Front"
                                                       action:@selector(arrangeInFront:)
                                                keyEquivalent:@""];
    frontItem.target = nil;
    [windowMenu addItem:frontItem];

    windowItem.submenu = windowMenu;
    NSApp.windowsMenu = windowMenu;
    NSApp.mainMenu = mainMenu;
}

@end
