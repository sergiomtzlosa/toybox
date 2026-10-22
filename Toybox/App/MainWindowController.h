#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface MainWindowController : NSWindowController

@property (nonatomic, readonly, getter=isRecording) BOOL recording;

- (instancetype)init;
- (void)silenceAllSounds;
- (void)shutdown;
- (void)toggleRecording:(nullable id)sender;
- (void)revealRecordingsFolder:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END
