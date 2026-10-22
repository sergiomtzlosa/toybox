#import "ToyMusic.h"

#include <math.h>

NSInteger ToyMIDINoteForFrequency(double frequency)
{
    if (!isfinite(frequency) || frequency <= 0.0) {
        return 69;
    }
    long note = lround(69.0 + 12.0 * log2(frequency / 440.0));
    return (NSInteger)MAX(0L, MIN(127L, note));
}

double ToyFrequencyForMIDINote(NSInteger midiNote)
{
    NSInteger clamped = MAX(0, MIN(127, midiNote));
    return 440.0 * pow(2.0, (clamped - 69) / 12.0);
}

NSString *ToyNoteNameForMIDINote(NSInteger midiNote)
{
    static NSString * const names[12] = {
        @"C", @"C#", @"D", @"D#", @"E", @"F",
        @"F#", @"G", @"G#", @"A", @"A#", @"B"
    };
    NSInteger clamped = MAX(0, MIN(127, midiNote));
    NSInteger pitchClass = clamped % 12;
    NSInteger octave = clamped / 12 - 1;
    return [NSString stringWithFormat:@"%@%ld", names[pitchClass], (long)octave];
}

NSString *ToyNoteNameForFrequency(double frequency)
{
    return ToyNoteNameForMIDINote(ToyMIDINoteForFrequency(frequency));
}
