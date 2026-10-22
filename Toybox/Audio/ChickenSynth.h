#ifndef ChickenSynth_h
#define ChickenSynth_h

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct ChickenSynth ChickenSynth;

ChickenSynth *ChickenSynthCreate(double sampleRate);
void ChickenSynthDestroy(ChickenSynth *synth);

/// 0 = relaxed, 1 = fully squeezed. Realtime-safe.
void ChickenSynthSetSqueeze(ChickenSynth *synth, double squeeze);

/// Starts one fresh squeaker note. Randomizes pitch and timbre.
void ChickenSynthTrigger(ChickenSynth *synth);

/// Renders mono signal into both channels. Realtime-safe.
void ChickenSynthRender(ChickenSynth *synth, float *left, float *right, uint32_t frameCount);

/// The base frequency of the current squawk (before pressure bending).
double ChickenSynthGetBaseFrequency(ChickenSynth *synth);

#ifdef __cplusplus
}
#endif

#endif /* ChickenSynth_h */
