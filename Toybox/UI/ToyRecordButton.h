#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

/// Small glass transport button that starts/stops a local audio recording.
@interface ToyRecordButton : NSButton

@property (nonatomic, assign, getter=isRecording) BOOL recording;
@property (nonatomic, copy) NSString *elapsedText;

@end

NS_ASSUME_NONNULL_END
