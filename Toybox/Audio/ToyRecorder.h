#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Captures the engine's stereo float output into a local 24-bit WAV file.
/// Sample buffers are handed off through a lock-free ring buffer; file I/O
/// happens on a private serial queue, never on the render thread.
@interface ToyRecorder : NSObject

@property (nonatomic, readonly, getter=isRecording) BOOL recording;
@property (nonatomic, readonly, nullable) NSURL *lastRecordingURL;

/// ~/Music/Toybox Recordings
+ (NSURL *)recordingsDirectoryURL;

- (BOOL)startRecordingWithFormat:(AVAudioFormat *)format error:(NSError **)error;
- (void)appendBuffer:(AVAudioPCMBuffer *)buffer;

/// Stops accepting samples, drains the ring buffer, closes the file, and
/// reports the saved URL on the main queue.
- (void)finishRecordingWithCompletion:(void (^ _Nullable)(NSURL * _Nullable url,
                                                            NSError * _Nullable error))completion;

/// Used when the window/engine shuts down; blocks until the file is complete.
- (void)closeSynchronously;

@end

NS_ASSUME_NONNULL_END
