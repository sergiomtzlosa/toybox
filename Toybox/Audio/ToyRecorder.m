#import "ToyRecorder.h"

#import <os/log.h>

#include <stdatomic.h>
#include <stdlib.h>

static const uint32_t kToyRecorderRingFrames = 1u << 20; // must be a power of two
static const AVAudioFrameCount kToyRecorderWriteChunk = 8192;

@implementation ToyRecorder {
    dispatch_queue_t _writerQueue;
    dispatch_source_t _writerTimer;
    AVAudioFile *_file;
    NSURL *_lastRecordingURL;
    NSError *_writeError;

    float *_ring;
    _Atomic uint64_t _writeFrame;
    _Atomic uint64_t _readFrame;
    _Atomic uint64_t _droppedFrames;
    _Atomic bool _acceptingSamples;

    BOOL _recording;
    BOOL _finishing;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _writerQueue = dispatch_queue_create("com.sid.toybox.recorder", DISPATCH_QUEUE_SERIAL);
        _ring = calloc((size_t)kToyRecorderRingFrames * 2u, sizeof(float));
        if (!_ring) {
            return nil;
        }
        atomic_init(&_writeFrame, 0);
        atomic_init(&_readFrame, 0);
        atomic_init(&_droppedFrames, 0);
        atomic_init(&_acceptingSamples, false);
    }
    return self;
}

- (void)dealloc
{
    if (_writerTimer) {
        dispatch_source_cancel(_writerTimer);
        _writerTimer = nil;
    }
    _file = nil;
    free(_ring);
    _ring = NULL;
}

+ (NSURL *)recordingsDirectoryURL
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *musicURL = [fileManager URLForDirectory:NSMusicDirectory
                                          inDomain:NSUserDomainMask
                                 appropriateForURL:nil
                                            create:NO
                                             error:NULL];
    if (!musicURL) {
        musicURL = [NSURL fileURLWithPath:NSHomeDirectory() isDirectory:YES];
    }
    return [musicURL URLByAppendingPathComponent:@"Toybox Recordings" isDirectory:YES];
}

- (BOOL)isRecording
{
    return _recording;
}

- (NSURL *)lastRecordingURL
{
    return _lastRecordingURL;
}

- (BOOL)startRecordingWithFormat:(AVAudioFormat *)format error:(NSError **)error
{
    if (_recording || _finishing) {
        if (error) {
            *error = [NSError errorWithDomain:@"ToyboxRecorder"
                                         code:1
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    @"A recording is already being finished."}];
        }
        return NO;
    }
    if (!format || format.channelCount == 0 || format.sampleRate < 8000.0 || !_ring) {
        if (error) {
            *error = [NSError errorWithDomain:@"ToyboxRecorder"
                                         code:2
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    @"The audio format is not ready for recording."}];
        }
        return NO;
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *directory = [ToyRecorder recordingsDirectoryURL];
    NSError *directoryError = nil;
    if (![fileManager createDirectoryAtURL:directory
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:&directoryError]) {
        if (error) {
            *error = directoryError;
        }
        return NO;
    }

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.dateFormat = @"yyyy-MM-dd 'at' HH.mm.ss";
    NSString *stamp = [formatter stringFromDate:[NSDate date]];
    NSURL *url = [directory URLByAppendingPathComponent:
        [NSString stringWithFormat:@"Toybox %@.wav", stamp]];

    NSDictionary *settings = @{
        AVFormatIDKey: @(kAudioFormatLinearPCM),
        AVSampleRateKey: @(format.sampleRate),
        AVNumberOfChannelsKey: @2,
        AVLinearPCMBitDepthKey: @24,
        AVLinearPCMIsFloatKey: @NO,
        AVLinearPCMIsBigEndianKey: @NO,
        AVLinearPCMIsNonInterleaved: @NO
    };

    NSError *fileError = nil;
    AVAudioFile *file = [[AVAudioFile alloc] initForWriting:url
                                                   settings:settings
                                               commonFormat:AVAudioPCMFormatFloat32
                                                interleaved:NO
                                                      error:&fileError];
    if (!file) {
        if (error) {
            *error = fileError;
        }
        return NO;
    }

    _file = file;
    _lastRecordingURL = url;
    _writeError = nil;
    _recording = YES;
    _finishing = NO;

    atomic_store_explicit(&_writeFrame, 0, memory_order_relaxed);
    atomic_store_explicit(&_readFrame, 0, memory_order_relaxed);
    atomic_store_explicit(&_droppedFrames, 0, memory_order_relaxed);
    atomic_store_explicit(&_acceptingSamples, true, memory_order_release);

    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _writerQueue);
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(timer, ^{
        [weakSelf drainRingToFile];
    });
    dispatch_source_set_timer(timer,
                              dispatch_time(DISPATCH_TIME_NOW, 0),
                              100ull * NSEC_PER_MSEC,
                              20ull * NSEC_PER_MSEC);
    _writerTimer = timer;
    dispatch_resume(timer);

    return YES;
}

- (void)appendBuffer:(AVAudioPCMBuffer *)buffer
{
    if (!atomic_load_explicit(&_acceptingSamples, memory_order_relaxed)) {
        return;
    }
    if (!buffer || buffer.frameLength == 0 || !buffer.floatChannelData) {
        return;
    }
    if (buffer.format.commonFormat != AVAudioPCMFormatFloat32) {
        return;
    }

    const AVAudioChannelCount sourceChannels = buffer.format.channelCount;
    if (sourceChannels == 0) {
        return;
    }

    uint64_t frames = buffer.frameLength;
    uint64_t writeIndex = atomic_load_explicit(&_writeFrame, memory_order_relaxed);
    uint64_t readIndex = atomic_load_explicit(&_readFrame, memory_order_acquire);
    uint64_t usedFrames = writeIndex - readIndex;
    if (usedFrames > kToyRecorderRingFrames) {
        usedFrames = kToyRecorderRingFrames;
    }
    uint64_t freeFrames = kToyRecorderRingFrames - usedFrames;
    if (frames > freeFrames) {
        atomic_fetch_add_explicit(&_droppedFrames, frames - freeFrames, memory_order_relaxed);
        frames = freeFrames;
    }
    if (frames == 0) {
        return;
    }

    const uint64_t mask = kToyRecorderRingFrames - 1;
    float * const *const source = buffer.floatChannelData;
    if (buffer.format.isInterleaved) {
        const float *interleaved = source[0];
        for (uint64_t frame = 0; frame < frames; frame++) {
            uint64_t ringIndex = ((writeIndex + frame) & mask) * 2u;
            _ring[ringIndex] = interleaved[frame * sourceChannels];
            _ring[ringIndex + 1] = sourceChannels > 1
                ? interleaved[frame * sourceChannels + 1]
                : interleaved[frame * sourceChannels];
        }
    } else {
        const float *left = source[0];
        const float *right = sourceChannels > 1 ? source[1] : left;
        for (uint64_t frame = 0; frame < frames; frame++) {
            uint64_t ringIndex = ((writeIndex + frame) & mask) * 2u;
            _ring[ringIndex] = left[frame];
            _ring[ringIndex + 1] = right[frame];
        }
    }

    atomic_store_explicit(&_writeFrame, writeIndex + frames, memory_order_release);
}

- (void)drainRingToFile
{
    AVAudioFile *file = _file;
    if (!file) {
        return;
    }

    AVAudioPCMBuffer *buffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:file.processingFormat
                                                             frameCapacity:kToyRecorderWriteChunk];
    if (!buffer) {
        return;
    }

    const AVAudioChannelCount outputChannels = file.processingFormat.channelCount;
    const uint64_t mask = kToyRecorderRingFrames - 1;

    for (;;) {
        uint64_t readIndex = atomic_load_explicit(&_readFrame, memory_order_relaxed);
        uint64_t writeIndex = atomic_load_explicit(&_writeFrame, memory_order_acquire);
        if (writeIndex <= readIndex) {
            break;
        }

        AVAudioFrameCount frames = (AVAudioFrameCount)MIN((uint64_t)kToyRecorderWriteChunk,
                                                          writeIndex - readIndex);
        buffer.frameLength = frames;
        float * const *const destination = buffer.floatChannelData;
        for (AVAudioFrameCount frame = 0; frame < frames; frame++) {
            uint64_t ringIndex = ((readIndex + frame) & mask) * 2u;
            destination[0][frame] = _ring[ringIndex];
            if (outputChannels > 1) {
                destination[1][frame] = _ring[ringIndex + 1];
            }
        }

        NSError *error = nil;
        if (![file writeFromBuffer:buffer error:&error]) {
            _writeError = error;
            os_log_error(OS_LOG_DEFAULT, "Toybox recording write failed: %{public}@", error);
            break;
        }
        atomic_store_explicit(&_readFrame, readIndex + frames, memory_order_release);
    }
}

- (void)finishOnWriterQueue
{
    if (_writerTimer) {
        dispatch_source_cancel(_writerTimer);
        _writerTimer = nil;
    }
    [self drainRingToFile];
    _file = nil;

    uint64_t dropped = atomic_load_explicit(&_droppedFrames, memory_order_relaxed);
    if (dropped > 0) {
        os_log_error(OS_LOG_DEFAULT, "Toybox recording dropped %llu frames",
                     (unsigned long long)dropped);
    }
}

- (void)finishRecordingWithCompletion:(void (^)(NSURL *, NSError *))completion
{
    if (!_recording) {
        NSURL *url = _lastRecordingURL;
        NSError *error = _writeError;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(url, error);
            }
        });
        return;
    }

    _recording = NO;
    _finishing = YES;
    atomic_store_explicit(&_acceptingSamples, false, memory_order_release);

    dispatch_async(_writerQueue, ^{
        [self finishOnWriterQueue];
        NSURL *url = self->_lastRecordingURL;
        NSError *error = self->_writeError;
        self->_finishing = NO;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(url, error);
            }
        });
    });
}

- (void)closeSynchronously
{
    _recording = NO;
    atomic_store_explicit(&_acceptingSamples, false, memory_order_release);

    dispatch_sync(_writerQueue, ^{
        if (self->_finishing) {
            return;
        }
        self->_finishing = YES;
        [self finishOnWriterQueue];
        self->_finishing = NO;
    });
}

@end
