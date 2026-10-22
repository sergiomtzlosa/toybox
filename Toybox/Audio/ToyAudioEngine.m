#import "ToyAudioEngine.h"
#import "ToyRecorder.h"

#import <AVFoundation/AVFoundation.h>
#import <os/log.h>

#include "OtamatoneSynth.h"
#include "ChickenSynth.h"
#include <string.h>

@interface ToyAudioEngine ()
@property (nonatomic, strong) AVAudioEngine *engine;
@property (nonatomic, strong) AVAudioSourceNode *otamatoneNode;
@property (nonatomic, strong) AVAudioSourceNode *chickenNode;
@property (nonatomic, strong) AVAudioUnitReverb *reverb;
@property (nonatomic, strong) AVAudioFormat *renderFormat;
@property (nonatomic, strong) ToyRecorder *recorder;
@property (nonatomic, assign) BOOL startRequested;
@property (nonatomic, assign) BOOL running;
@property (nonatomic, assign) BOOL recordingTapInstalled;
@end

@implementation ToyAudioEngine {
    OtamatoneSynth *_otamatoneSynth;
    ChickenSynth *_chickenSynth;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self configureGraph];
        _recorder = [[ToyRecorder alloc] init];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleEngineConfigurationChange:)
                                                     name:AVAudioEngineConfigurationChangeNotification
                                                   object:_engine];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (self.recordingTapInstalled) {
        [self.reverb removeTapOnBus:0];
        self.recordingTapInstalled = NO;
    }
    [self.recorder closeSynchronously];
    [_engine stop];
    _otamatoneNode = nil;
    _chickenNode = nil;
    _engine = nil;
    OtamatoneSynthDestroy(_otamatoneSynth);
    ChickenSynthDestroy(_chickenSynth);
    _otamatoneSynth = NULL;
    _chickenSynth = NULL;
}

- (void)configureGraph
{
    self.engine = [[AVAudioEngine alloc] init];

    double hardwareSampleRate = [self.engine.outputNode outputFormatForBus:0].sampleRate;
    if (!isfinite(hardwareSampleRate) || hardwareSampleRate < 8000.0) {
        hardwareSampleRate = 48000.0;
    }

    _sampleRate = hardwareSampleRate;
    self.renderFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32
                                                        sampleRate:hardwareSampleRate
                                                          channels:2
                                                       interleaved:NO];

    _otamatoneSynth = OtamatoneSynthCreate(hardwareSampleRate);
    _chickenSynth = ChickenSynthCreate(hardwareSampleRate);

    __block OtamatoneSynth *otamatoneSynth = _otamatoneSynth;
    __block ChickenSynth *chickenSynth = _chickenSynth;

    __weak typeof(self) weakSelf = self;
    self.otamatoneNode = [[AVAudioSourceNode alloc] initWithFormat:self.renderFormat
                                                      renderBlock:^OSStatus(
                                                          BOOL *isSilence,
                                                          const AudioTimeStamp *timestamp,
                                                          AVAudioFrameCount frameCount,
                                                          AudioBufferList *outputData) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        (void)strongSelf;
        (void)timestamp;
        if (isSilence) {
            *isSilence = NO;
        }
        if (outputData->mNumberBuffers >= 2) {
            float *left = (float *)outputData->mBuffers[0].mData;
            float *right = (float *)outputData->mBuffers[1].mData;
            if (left && right) {
                OtamatoneSynthRender(otamatoneSynth, left, right, (uint32_t)frameCount);
                return noErr;
            }
        }
        for (UInt32 bufferIndex = 0; bufferIndex < outputData->mNumberBuffers; bufferIndex++) {
            if (outputData->mBuffers[bufferIndex].mData) {
                memset(outputData->mBuffers[bufferIndex].mData, 0,
                       outputData->mBuffers[bufferIndex].mDataByteSize);
            }
        }
        return noErr;
    }];

    self.chickenNode = [[AVAudioSourceNode alloc] initWithFormat:self.renderFormat
                                                     renderBlock:^OSStatus(
                                                         BOOL *isSilence,
                                                         const AudioTimeStamp *timestamp,
                                                         AVAudioFrameCount frameCount,
                                                         AudioBufferList *outputData) {
        (void)timestamp;
        if (isSilence) {
            *isSilence = NO;
        }
        if (outputData->mNumberBuffers >= 2) {
            float *left = (float *)outputData->mBuffers[0].mData;
            float *right = (float *)outputData->mBuffers[1].mData;
            if (left && right) {
                ChickenSynthRender(chickenSynth, left, right, (uint32_t)frameCount);
                return noErr;
            }
        }
        for (UInt32 bufferIndex = 0; bufferIndex < outputData->mNumberBuffers; bufferIndex++) {
            if (outputData->mBuffers[bufferIndex].mData) {
                memset(outputData->mBuffers[bufferIndex].mData, 0,
                       outputData->mBuffers[bufferIndex].mDataByteSize);
            }
        }
        return noErr;
    }];

    self.reverb = [[AVAudioUnitReverb alloc] init];
    [self.reverb loadFactoryPreset:AVAudioUnitReverbPresetMediumRoom];
    self.reverb.wetDryMix = 12.0;

    AVAudioEngine *engine = self.engine;
    [engine attachNode:self.otamatoneNode];
    [engine attachNode:self.chickenNode];
    [engine attachNode:self.reverb];

    [engine connect:self.otamatoneNode to:engine.mainMixerNode format:self.renderFormat];
    [engine connect:self.chickenNode to:engine.mainMixerNode format:self.renderFormat];
    [engine connect:engine.mainMixerNode to:self.reverb format:nil];
    [engine connect:self.reverb to:engine.outputNode format:nil];

    engine.mainMixerNode.outputVolume = 0.92;
    [engine prepare];
}

- (BOOL)start
{
    if (self.running) {
        return YES;
    }

    self.startRequested = YES;

    NSError *error = nil;
    if (![self.engine startAndReturnError:&error]) {
        os_log_error(OS_LOG_DEFAULT, "Toybox audio engine failed to start: %{public}@", error);
        self.running = NO;
        return NO;
    }

    self.running = YES;
    return YES;
}

- (void)stop
{
    self.startRequested = NO;
    if (self.recordingTapInstalled) {
        [self.reverb removeTapOnBus:0];
        self.recordingTapInstalled = NO;
    }
    [self.recorder closeSynchronously];
    [self stopAllSounds];
    [self.engine stop];
    self.running = NO;
}

- (BOOL)isRecording
{
    return self.recorder.isRecording;
}

- (BOOL)startRecordingWithError:(NSError **)error
{
    if (self.recorder.isRecording) {
        return YES;
    }
    if (!self.recorder) {
        if (error) {
            *error = [NSError errorWithDomain:@"ToyboxAudioEngine"
                                         code:1
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    @"The recorder is unavailable."}];
        }
        return NO;
    }
    if (!self.engine.isRunning && ![self start]) {
        if (error) {
            *error = [NSError errorWithDomain:@"ToyboxAudioEngine"
                                         code:2
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    @"The audio engine could not be started."}];
        }
        return NO;
    }

    AVAudioFormat *tapFormat = [self.reverb outputFormatForBus:0];
    if (!tapFormat || tapFormat.channelCount == 0 || tapFormat.sampleRate < 8000.0) {
        tapFormat = self.renderFormat;
    }

    NSError *recordError = nil;
    if (![self.recorder startRecordingWithFormat:tapFormat error:&recordError]) {
        if (error) {
            *error = recordError;
        }
        return NO;
    }

    ToyRecorder *recorder = self.recorder;
    [self.reverb installTapOnBus:0
                      bufferSize:4096
                          format:tapFormat
                           block:^(AVAudioPCMBuffer *buffer, AVAudioTime *when) {
        (void)when;
        [recorder appendBuffer:buffer];
    }];
    self.recordingTapInstalled = YES;
    return YES;
}

- (void)stopRecordingWithCompletion:(void (^)(NSURL *, NSError *))completion
{
    if (self.recordingTapInstalled) {
        [self.reverb removeTapOnBus:0];
        self.recordingTapInstalled = NO;
    }
    [self.recorder finishRecordingWithCompletion:completion];
}

- (double)chickenFrequency
{
    return ChickenSynthGetBaseFrequency(_chickenSynth);
}

- (void)stopAllSounds
{
    OtamatoneSynthSetGate(_otamatoneSynth, 0.0);
    OtamatoneSynthSetMouth(_otamatoneSynth, 0.0);
    ChickenSynthSetSqueeze(_chickenSynth, 0.0);
}

- (void)setOtamatoneGate:(double)gate
{
    OtamatoneSynthSetGate(_otamatoneSynth, gate);
}

- (void)setOtamatoneFrequency:(double)frequency
{
    OtamatoneSynthSetFrequency(_otamatoneSynth, frequency);
}

- (void)setOtamatoneMouth:(double)mouth
{
    OtamatoneSynthSetMouth(_otamatoneSynth, mouth);
}

- (void)triggerChicken
{
    ChickenSynthTrigger(_chickenSynth);
}

- (void)setChickenSqueeze:(double)squeeze
{
    ChickenSynthSetSqueeze(_chickenSynth, squeeze);
}

- (void)handleEngineConfigurationChange:(NSNotification *)notification
{
    (void)notification;
    if (!self.startRequested) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.startRequested || self.engine.isRunning) {
            return;
        }
        NSError *error = nil;
        if ([self.engine startAndReturnError:&error]) {
            self.running = YES;
        } else {
            self.running = NO;
            os_log_error(OS_LOG_DEFAULT, "Toybox audio engine restart failed: %{public}@", error);
        }
    });
}

@end
