#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Owns the AVAudioEngine graph and both real-time synth voices.
@interface ToyAudioEngine : NSObject

@property (nonatomic, readonly) BOOL running;
@property (nonatomic, readonly) double sampleRate;
@property (nonatomic, readonly) BOOL recording;
@property (nonatomic, readonly) double chickenFrequency;

- (BOOL)start;
- (void)stop;
- (void)stopAllSounds;

/// Captures the final mixed output (including room reverb) to a WAV file.
- (BOOL)startRecordingWithError:(NSError **)error;
- (void)stopRecordingWithCompletion:(void (^ _Nullable)(NSURL * _Nullable url,
                                                         NSError * _Nullable error))completion;

// Otamatone
- (void)setOtamatoneGate:(double)gate;
- (void)setOtamatoneFrequency:(double)frequency;
- (void)setOtamatoneMouth:(double)mouth;

// Rubber chicken
- (void)triggerChicken;
- (void)setChickenSqueeze:(double)squeeze;

@end

NS_ASSUME_NONNULL_END
