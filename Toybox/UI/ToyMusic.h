#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Nearest equal-tempered MIDI note for a frequency (A4 = 69 = 440 Hz).
NSInteger ToyMIDINoteForFrequency(double frequency);
double ToyFrequencyForMIDINote(NSInteger midiNote);
NSString *ToyNoteNameForMIDINote(NSInteger midiNote);
NSString *ToyNoteNameForFrequency(double frequency);

NS_ASSUME_NONNULL_END
