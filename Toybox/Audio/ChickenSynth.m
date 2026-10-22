#import <Foundation/Foundation.h>
#include "ChickenSynth.h"
#include "SynthDSP.h"
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>

struct ChickenSynth {
    double sampleRate;

    _Atomic double targetSqueeze;
    _Atomic uint32_t triggerCounter;
    _Atomic double publishedBaseFrequency;

    uint32_t lastTrigger;
    double squeeze;
    double envelope;

    double phase;
    double subPhase;
    double age;
    double baseFrequency;
    double pulseWidth;
    double flutterRate;
    double flutterPhase;
    double wobblePhase;
    double onsetNoise;
    double driftPhase;
    double driftValue;
    double driftCoefficient;

    double squeezeAttackCoefficient;
    double squeezeReleaseCoefficient;
    double envelopeAttackCoefficient;
    double envelopeReleaseCoefficient;
    double onsetDecay;

    double dcInput;
    double dcOutput;

    ToyBiquad highpass;
    ToyBiquad nasalPeak;
    ToyBiquad upperPeak;
    ToyBiquad lowpass;

    uint32_t randomState;
    uint32_t filterUpdateCountdown;
};

static const double kChickenSquawkFrequencies[] = {
    880.000,   // A5
    1046.502,  // C6
    1174.659,  // D6
    1318.510,  // E6
    1567.982   // G6
};

static void ChickenRandomizeNote(ChickenSynth *synth)
{
    uint32_t scaleIndex = (uint32_t)(ToyRandomUnit(&synth->randomState) * 5.0);
    if (scaleIndex > 4) {
        scaleIndex = 4;
    }
    synth->baseFrequency = kChickenSquawkFrequencies[scaleIndex];
    atomic_store_explicit(&synth->publishedBaseFrequency, synth->baseFrequency,
                          memory_order_relaxed);
    synth->pulseWidth = 0.24 + ToyRandomUnit(&synth->randomState) * 0.22;
    synth->flutterRate = 24.0 + ToyRandomUnit(&synth->randomState) * 17.0;
    synth->age = 0.0;
    synth->phase = 0.0;
    synth->subPhase = 0.0;
    synth->flutterPhase = ToyRandomUnit(&synth->randomState) * M_PI * 2.0;
    synth->wobblePhase = ToyRandomUnit(&synth->randomState) * M_PI * 2.0;
    synth->driftPhase = ToyRandomUnit(&synth->randomState);
    synth->onsetNoise = 1.0;
    if (synth->envelope < 0.22) {
        synth->envelope = 0.22;
    }
}

ChickenSynth *ChickenSynthCreate(double sampleRate)
{
    if (sampleRate < 8000.0) {
        sampleRate = 44100.0;
    }

    ChickenSynth *synth = (ChickenSynth *)calloc(1, sizeof(ChickenSynth));
    if (!synth) {
        return NULL;
    }

    synth->sampleRate = sampleRate;
    atomic_init(&synth->targetSqueeze, 0.0);
    atomic_init(&synth->triggerCounter, 0);
    atomic_init(&synth->publishedBaseFrequency, 1180.0);
    synth->lastTrigger = 0;
    synth->squeeze = 0.0;
    synth->envelope = 0.0;
    synth->baseFrequency = 1180.0;
    synth->pulseWidth = 0.34;
    synth->flutterRate = 31.0;
    synth->flutterPhase = 0.7;
    synth->wobblePhase = 1.2;
    synth->onsetNoise = 0.0;
    synth->driftPhase = 0.2;
    synth->squeezeAttackCoefficient = ToyOnePoleCoefficient(0.018, sampleRate);
    synth->squeezeReleaseCoefficient = ToyOnePoleCoefficient(0.14, sampleRate);
    synth->envelopeAttackCoefficient = ToyOnePoleCoefficient(0.009, sampleRate);
    synth->envelopeReleaseCoefficient = ToyOnePoleCoefficient(0.16, sampleRate);
    synth->onsetDecay = ToyOnePoleCoefficient(0.032, sampleRate);
    synth->driftCoefficient = ToyOnePoleCoefficient(0.09, sampleRate);
    synth->randomState = 0xC4A5E31Bu ^ (uint32_t)(sampleRate * 7.0);
    synth->filterUpdateCountdown = 0;

    ToyBiquadSetHighpass(&synth->highpass, sampleRate, 430.0, 0.72);
    ToyBiquadSetPeaking(&synth->nasalPeak, sampleRate, 1760.0, 1.15, 8.2);
    ToyBiquadSetPeaking(&synth->upperPeak, sampleRate, 3200.0, 1.55, 4.5);
    ToyBiquadSetLowpass(&synth->lowpass, sampleRate, 7600.0, 0.7);

    return synth;
}

void ChickenSynthDestroy(ChickenSynth *synth)
{
    free(synth);
}

void ChickenSynthSetSqueeze(ChickenSynth *synth, double squeeze)
{
    if (!synth) {
        return;
    }
    atomic_store_explicit(&synth->targetSqueeze, ToyDSPClamp(squeeze, 0.0, 1.0),
                          memory_order_relaxed);
}

void ChickenSynthTrigger(ChickenSynth *synth)
{
    if (!synth) {
        return;
    }
    atomic_fetch_add_explicit(&synth->triggerCounter, 1u, memory_order_relaxed);
}

double ChickenSynthGetBaseFrequency(ChickenSynth *synth)
{
    if (!synth) {
        return 0.0;
    }
    return atomic_load_explicit(&synth->publishedBaseFrequency, memory_order_relaxed);
}

static void ChickenUpdateFilters(ChickenSynth *synth)
{
    double squeeze = ToyDSPClamp(synth->squeeze, 0.0, 1.0);
    ToyBiquadSetHighpass(&synth->highpass, synth->sampleRate, 420.0, 0.72);
    ToyBiquadSetPeaking(&synth->nasalPeak, synth->sampleRate,
                        1700.0 + 720.0 * squeeze, 1.12, 8.4);
    ToyBiquadSetPeaking(&synth->upperPeak, synth->sampleRate,
                        3150.0 + 520.0 * squeeze, 1.55, 4.7);
    ToyBiquadSetLowpass(&synth->lowpass, synth->sampleRate,
                        7300.0 + 700.0 * squeeze, 0.7);
}

void ChickenSynthRender(ChickenSynth *synth, float *left, float *right, uint32_t frameCount)
{
    if (!synth || !left || !right || frameCount == 0) {
        return;
    }

    const double sampleRate = synth->sampleRate;
    const double twoPi = 2.0 * M_PI;
    const uint32_t trigger = atomic_load_explicit(&synth->triggerCounter, memory_order_relaxed);
    if (trigger != synth->lastTrigger) {
        synth->lastTrigger = trigger;
        ChickenRandomizeNote(synth);
    }

    const double squeezeTarget = ToyDSPClamp(
        atomic_load_explicit(&synth->targetSqueeze, memory_order_relaxed), 0.0, 1.0);

    for (uint32_t frame = 0; frame < frameCount; frame++) {
        double squeezeCoefficient = squeezeTarget > synth->squeeze
                                  ? synth->squeezeAttackCoefficient
                                  : synth->squeezeReleaseCoefficient;
        synth->squeeze += (squeezeTarget - synth->squeeze) * squeezeCoefficient;

        double pressure = ToySmoothstepDouble(0.015, 0.52, synth->squeeze);
        double gateTarget = pressure * (0.52 + 0.48 * synth->squeeze);
        double envelopeCoefficient = gateTarget > synth->envelope
                                   ? synth->envelopeAttackCoefficient
                                   : synth->envelopeReleaseCoefficient;
        synth->envelope += (gateTarget - synth->envelope) * envelopeCoefficient;

        synth->age += 1.0 / sampleRate;
        synth->flutterPhase += twoPi * synth->flutterRate / sampleRate;
        if (synth->flutterPhase > twoPi) {
            synth->flutterPhase -= twoPi;
        }
        synth->wobblePhase += twoPi * 6.3 / sampleRate;
        if (synth->wobblePhase > twoPi) {
            synth->wobblePhase -= twoPi;
        }
        synth->driftPhase += 0.23 / sampleRate;
        if (synth->driftPhase >= 1.0) {
            synth->driftPhase -= 1.0;
        }

        double driftRandom = ToyNoiseBipolar(&synth->randomState);
        synth->driftValue += (driftRandom - synth->driftValue) * synth->driftCoefficient;
        synth->onsetNoise *= (1.0 - synth->onsetDecay);

        double pressurePitch = 0.74 + 0.58 * synth->squeeze;
        double attackChirp = 1.0 + 0.24 * exp(-synth->age / 0.045);
        double squawkContour = 1.0 + 0.12 * sin(M_PI * fmin(synth->age / 0.21, 1.0));
        double flutter = sin(synth->flutterPhase) * 0.042;
        double wobble = sin(synth->wobblePhase) * 0.020;
        double slowDrift = sin(twoPi * synth->driftPhase) * 0.010 + synth->driftValue * 0.012;

        double frequency = synth->baseFrequency * pressurePitch * attackChirp * squawkContour;
        frequency *= (1.0 + flutter + wobble + slowDrift);
        frequency = fmin(fmax(frequency, 190.0), sampleRate * 0.40);

        double dt = frequency / sampleRate;
        synth->phase += dt;
        if (synth->phase >= 1.0) {
            synth->phase -= 1.0;
        }
        double subDt = dt * 0.5;
        synth->subPhase += subDt;
        if (synth->subPhase >= 1.0) {
            synth->subPhase -= 1.0;
        }

        double pulse = ToyBandlimitedPulse(synth->phase, synth->pulseWidth, dt);
        double saw = ToyBandlimitedSaw(synth->phase, dt);
        double subSaw = ToyBandlimitedSaw(synth->subPhase, subDt);
        double noise = ToyNoiseBipolar(&synth->randomState);

        double source = pulse * 0.62 + saw * 0.28 + subSaw * 0.10;
        source += noise * (0.13 + synth->onsetNoise * 0.30);
        source = ToyBiquadProcess(&synth->highpass, source);

        if (synth->filterUpdateCountdown == 0) {
            ChickenUpdateFilters(synth);
            synth->filterUpdateCountdown = 24;
        }
        synth->filterUpdateCountdown--;

        double shaped = ToyBiquadProcess(&synth->nasalPeak, source);
        shaped = ToyBiquadProcess(&synth->upperPeak, shaped);
        shaped = ToySoftClip(shaped * 3.7);
        shaped = ToyBiquadProcess(&synth->lowpass, shaped);

        double flutterAM = 0.80 + 0.20 * sin(synth->flutterPhase * 1.02 + 0.65);
        double slowAM = 0.93 + 0.07 * sin(synth->wobblePhase * 0.37);
        double output = shaped * synth->envelope * flutterAM * slowAM * 0.32;
        output = ToySoftClip(output * 1.35) * 0.86;

        double dcOutput = output - synth->dcInput + 0.9985 * synth->dcOutput;
        synth->dcInput = output;
        synth->dcOutput = dcOutput;

        if (!isfinite(dcOutput)) {
            dcOutput = 0.0;
            ToyBiquadReset(&synth->highpass);
            ToyBiquadReset(&synth->nasalPeak);
            ToyBiquadReset(&synth->upperPeak);
            ToyBiquadReset(&synth->lowpass);
            synth->dcInput = 0.0;
            synth->dcOutput = 0.0;
        }

        left[frame] = (float)dcOutput;
        right[frame] = (float)dcOutput;
    }
}
