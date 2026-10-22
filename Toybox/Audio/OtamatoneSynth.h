#ifndef OtamatoneSynth_h
#define OtamatoneSynth_h

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct OtamatoneSynth OtamatoneSynth;

OtamatoneSynth *OtamatoneSynthCreate(double sampleRate);
void OtamatoneSynthDestroy(OtamatoneSynth *synth);

void OtamatoneSynthSetGate(OtamatoneSynth *synth, double gate);
void OtamatoneSynthSetFrequency(OtamatoneSynth *synth, double frequency);
void OtamatoneSynthSetMouth(OtamatoneSynth *synth, double mouth);

/// Renders mono signal into both channels. Realtime-safe.
void OtamatoneSynthRender(OtamatoneSynth *synth, float *left, float *right, uint32_t frameCount);

#ifdef __cplusplus
}
#endif

#endif /* OtamatoneSynth_h */
