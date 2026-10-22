#import "MainWindowController.h"

#import "ChickenView.h"
#import "OtamatoneView.h"
#import "StageView.h"
#import "ToyAudioEngine.h"
#import "ToyPanelView.h"
#import "ToyRecorder.h"
#import "ToyRecordButton.h"
#import "ToyTheme.h"
#import <QuartzCore/QuartzCore.h>
#include <math.h>

@interface MainWindowController () <NSWindowDelegate>
@property (nonatomic, strong) ToyAudioEngine *audioEngine;
@property (nonatomic, strong) StageView *stageView;
@property (nonatomic, strong) OtamatoneView *otamatoneView;
@property (nonatomic, strong) ChickenView *chickenView;
@property (nonatomic, strong) NSTimer *recordingTimer;
@property (nonatomic, assign) NSTimeInterval recordingStartedAt;
@property (nonatomic, assign) BOOL recordingActive;
@end

@implementation MainWindowController

- (instancetype)init
{
    NSRect contentRect = NSMakeRect(0.0, 0.0, 1180.0, 800.0);
    NSWindowStyleMask style = NSWindowStyleMaskTitled |
                              NSWindowStyleMaskClosable |
                              NSWindowStyleMaskMiniaturizable |
                              NSWindowStyleMaskResizable;
    NSWindow *window = [[NSWindow alloc] initWithContentRect:contentRect
                                                   styleMask:style
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    self = [super initWithWindow:window];
    if (self) {
        window.title = @"Toybox";
        window.titleVisibility = NSWindowTitleHidden;
        window.titlebarAppearsTransparent = YES;
        window.titlebarSeparatorStyle = NSTitlebarSeparatorStyleNone;
        window.backgroundColor = ToyColor(0x0A0D12, 1.0);
        window.contentMinSize = NSMakeSize(980.0, 680.0);
        window.minSize = NSMakeSize(980.0, 708.0);
        window.tabbingMode = NSWindowTabbingModeDisallowed;
        window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
        window.releasedWhenClosed = NO;
        window.delegate = self;
        window.collectionBehavior = NSWindowCollectionBehaviorFullScreenPrimary;

        _audioEngine = [[ToyAudioEngine alloc] init];
        BOOL audioStarted = [_audioEngine start];

        StageView *stage = [[StageView alloc] initWithFrame:contentRect];
        stage.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        _stageView = stage;
        stage.recordButton.target = self;
        stage.recordButton.action = @selector(toggleRecording:);

        OtamatoneView *otamatoneView = [[OtamatoneView alloc] initWithAudioEngine:_audioEngine];
        ChickenView *chickenView = [[ChickenView alloc] initWithAudioEngine:_audioEngine];
        _otamatoneView = otamatoneView;
        _chickenView = chickenView;

        ToyPanelView *otamatonePanel = [[ToyPanelView alloc]
            initWithTitle:@"OTAMATONE"
                 subtitle:@"Hold the face. Drag the neck to play notes."
                   number:@"01"
                     hint:@"HOLD TO SING   ·   DRAG TO PLAY NOTES"
                   accent:ToyColor(0x7FE6D0, 1.0)
                  toyView:otamatoneView];

        ToyPanelView *chickenPanel = [[ToyPanelView alloc]
            initWithTitle:@"RUBBER CHICKEN"
                 subtitle:@"Squeeze the body. Every squawk is a note."
                   number:@"02"
                     hint:@"PRESS AND HOLD   ·   ONE NOTE PER SQUEEZE"
                   accent:ToyColor(0xF2C34E, 1.0)
                  toyView:chickenView];

        stage.panels = @[otamatonePanel, chickenPanel];
        stage.audioOnline = audioStarted;
        if (audioStarted) {
            stage.audioStatusText = [NSString stringWithFormat:@"AUDIO LIVE  ·  %.1f KHZ",
                                     _audioEngine.sampleRate / 1000.0];
        } else {
            stage.audioStatusText = @"AUDIO OFFLINE";
        }

        window.contentView = stage;
        [window center];
        [window setFrameAutosaveName:@"ToyboxMainWindow"];
    }
    return self;
}

- (void)showWindow:(id)sender
{
    [super showWindow:sender];
    [self.window makeKeyAndOrderFront:sender];
    [NSApp activateIgnoringOtherApps:YES];
}

- (BOOL)isRecording
{
    return self.recordingActive;
}

- (void)toggleRecording:(id)sender
{
    (void)sender;
    if (self.recordingActive) {
        [self stopPerformanceRecording];
    } else {
        [self startPerformanceRecording];
    }
}

- (void)startPerformanceRecording
{
    if (self.recordingActive) {
        return;
    }

    NSError *error = nil;
    if (![self.audioEngine startRecordingWithError:&error]) {
        [self presentRecordingError:error];
        return;
    }

    self.recordingActive = YES;
    self.recordingStartedAt = CACurrentMediaTime();
    self.stageView.recordButton.recording = YES;
    self.stageView.recordButton.elapsedText = @"00:00";
    [self.stageView.recordButton setNeedsDisplay:YES];
    [self startRecordingTimer];
}

- (void)stopPerformanceRecording
{
    if (!self.recordingActive) {
        return;
    }

    self.recordingActive = NO;
    [self.recordingTimer invalidate];
    self.recordingTimer = nil;
    self.stageView.recordButton.recording = NO;
    self.stageView.recordButton.elapsedText = @"00:00";
    self.stageView.recordButton.enabled = NO;

    __weak typeof(self) weakSelf = self;
    [self.audioEngine stopRecordingWithCompletion:^(NSURL *url, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) {
                return;
            }
            self.stageView.recordButton.enabled = YES;
            if (error) {
                [self presentRecordingError:error];
                return;
            }
            if (url) {
                [self showSavedRecordingAlertForURL:url];
            }
        });
    }];
}

- (void)startRecordingTimer
{
    [self.recordingTimer invalidate];
    __weak typeof(self) weakSelf = self;
    NSTimer *timer = [NSTimer timerWithTimeInterval:0.25
                                           repeats:YES
                                             block:^(NSTimer *unusedTimer) {
        (void)unusedTimer;
        [weakSelf updateRecordingElapsedTime];
    }];
    self.recordingTimer = timer;
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    [self updateRecordingElapsedTime];
}

- (void)updateRecordingElapsedTime
{
    if (!self.recordingActive) {
        return;
    }
    NSTimeInterval elapsed = CACurrentMediaTime() - self.recordingStartedAt;
    NSUInteger totalSeconds = (NSUInteger)MAX(0.0, floor(elapsed));
    self.stageView.recordButton.elapsedText =
        [NSString stringWithFormat:@"%02lu:%02lu",
         (unsigned long)(totalSeconds / 60u),
         (unsigned long)(totalSeconds % 60u)];
}

- (void)presentRecordingError:(NSError *)error
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleWarning;
    alert.messageText = @"Recording unavailable";
    alert.informativeText = error.localizedDescription ?: @"The performance could not be saved.";
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}

- (void)showSavedRecordingAlertForURL:(NSURL *)url
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleInformational;
    alert.messageText = @"Recording saved";
    alert.informativeText = [NSString stringWithFormat:
        @"%@\n\nEverything you played was captured as a 24-bit WAV file.",
        url.path];
    [alert addButtonWithTitle:@"Show in Finder"];
    [alert addButtonWithTitle:@"Done"];
    NSModalResponse response = [alert runModal];
    if (response == NSAlertFirstButtonReturn) {
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[url]];
    }
}

- (void)revealRecordingsFolder:(id)sender
{
    (void)sender;
    NSURL *directory = [ToyRecorder recordingsDirectoryURL];
    [[NSFileManager defaultManager] createDirectoryAtURL:directory
                             withIntermediateDirectories:YES
                                              attributes:nil
                                                   error:NULL];
    [[NSWorkspace sharedWorkspace] openURL:directory];
}

- (void)shutdown
{
    [self.recordingTimer invalidate];
    self.recordingTimer = nil;
    [self.audioEngine stop];
}

- (void)silenceAllSounds
{
    [self.audioEngine stopAllSounds];
}

- (void)windowWillClose:(NSNotification *)notification
{
    (void)notification;
    [self.recordingTimer invalidate];
    self.recordingTimer = nil;
    [self.audioEngine stop];
}

@end
