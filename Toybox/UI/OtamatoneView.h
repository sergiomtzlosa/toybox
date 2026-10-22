#import <Cocoa/Cocoa.h>

@class ToyAudioEngine;

NS_ASSUME_NONNULL_BEGIN

@interface OtamatoneView : NSView

- (instancetype)initWithAudioEngine:(ToyAudioEngine *)audioEngine;
- (void)cancelInteraction;

@end

NS_ASSUME_NONNULL_END
