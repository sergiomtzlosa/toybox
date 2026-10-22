#import <Foundation/Foundation.h>
#include "OtamatoneSynth.h"
#include "SynthDSP.h"
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>

struct OtamatoneSynth {
    double sampleRate;

    _Atomic double targetGate;
    _Atomic double targetFrequency;
    _Atomic double targetMouth;

    double gate;
    double frequency;
    double mouth;

    double phaseA;
    double phaseB;
    double vibratoPhase;
    double driftPhase;
    double jawPhase;

    double attackCoefficient;
    double releaseCoefficient;
    double pitchCoefficient;
    double mouthCoefficient;
    double driftCoefficient;
    double driftValue;
    double chiff;
    double previousGateTarget;

    double dcInput;
    double dcOutput;

    ToyBiquad formantOne;
    ToyBiquad formantTwo;
    ToyBiquad formantThree;
    ToyBiquad nasal;
    ToyBiquad wah;
    ToyBiquad lowpass;

    uint32_t noiseState;
    uint32_t filterUpdateCountdown;
};

static double OtamatoneClampFrequency(double frequency)
{
    return fmin(fmax(frequency, 55.0), 1600.0);
}

OtamatoneSynth *OtamatoneSynthCreate(double sampleRate)
{
    if (sampleRate < 8000.0) {
        sampleRate = 44100.0;
    }

    OtamatoneSynth *synth = (OtamatoneSynth *)calloc(1, sizeof(OtamatoneSynth));
    if (!synth) {
        return NULL;
    }

    synth->sampleRate = sampleRate;
    atomic_init(&synth->targetGate, 0.0);
    atomic_init(&synth->targetFrequency, 220.0);
    atomic_init(&synth->targetMouth, 0.2);

    synth->gate = 0.0;
    synth->frequency = 220.0;
    synth->mouth = 0.2;
    synth->phaseA = 0.0;
    synth->phaseB = 0.21;
    synth->vibratoPhase = 0.0;
    synth->driftPhase = 0.31;
    synth->jawPhase = 0.63;
    synth->attackCoefficient = ToyOnePoleCoefficient(0.022, sampleRate);
    synth->releaseCoefficient = ToyOnePoleCoefficient(0.135, sampleRate);
    synth->pitchCoefficient = ToyOnePoleCoefficient(0.028, sampleRate);
    synth->mouthCoefficient = ToyOnePoleCoefficient(0.026, sampleRate);
    synth->driftCoefficient = ToyOnePoleCoefficient(0.16, sampleRate);
    synth->driftValue = 0.0;
    synth->noiseState = 0x51F2A3D7u ^ (uint32_t)(sampleRate * 3.0);
    synth->filterUpdateCountdown = 0;

    ToyBiquadSetBandpass(&synth->formantOne, sampleRate, 330.0, 5.2);
    ToyBiquadSetBandpass(&synth->formantTwo, sampleRate, 900.0, 6.4);
    ToyBiquadSetBandpass(&synth->formantThree, sampleRate, 2280.0, 7.0);
    ToyBiquadSetPeaking(&synth->nasal, sampleRate, 1080.0, 1.05, 5.0);
    ToyBiquadSetBandpass(&synth->wah, sampleRate, 560.0, 2.8);
    ToyBiquadSetLowpass(&synth->lowpass, sampleRate, 5900.0, 0.7);

    return synth;
}

void OtamatoneSynthDestroy(OtamatoneSynth *synth)
{
    free(synth);
}

void OtamatoneSynthSetGate(OtamatoneSynth *synth, double gate)
{
    if (!synth) {
        return;
    }
    atomic_store_explicit(&synth->targetGate, ToyDSPClamp(gate, 0.0, 1.0), memory_order_relaxed);
}

void OtamatoneSynthSetFrequency(OtamatoneSynth *synth, double frequency)
{
    if (!synth) {
        return;
    }
    atomic_store_explicit(&synth->targetFrequency, OtamatoneClampFrequency(frequency),
                          memory_order_relaxed);
}

void OtamatoneSynthSetMouth(OtamatoneSynth *synth, double mouth)
{
    if (!synth) {
        return;
    }
    atomic_store_explicit(&synth->targetMouth, ToyDSPClamp(mouth, 0.0, 1.0),
                          memory_order_relaxed);
}

static void OtamatoneUpdateFilters(OtamatoneSynth *synth, double mouth)
{
    double sampleRate = synth->sampleRate;

    double f1 = 300.0 + mouth * 510.0;   // "oo" -> "ah"
    double f2 = 860.0 + mouth * 300.0;
    double f3 = 2240.0 + mouth * 690.0;

    ToyBiquadSetBandpass(&synth->formantOne, sampleRate, f1, 5.4);
    ToyBiquadSetBandpass(&synth->formantTwo, sampleRate, f2, 6.6);
    ToyBiquadSetBandpass(&synth->formantThree, sampleRate, f3, 7.2);
    ToyBiquadSetPeaking(&synth->nasal, sampleRate, 1040.0 + mouth * 180.0, 1.05, 5.6);
    ToyBiquadSetBandpass(&synth->wah, sampleRate, 470.0 + mouth * 1180.0, 2.9);
    ToyBiquadSetLowpass(&synth->lowpass, sampleRate, 5600.0 + mouth * 1550.0, 0.68);
}

void OtamatoneSynthRender(OtamatoneSynth *synth, float *left, float *right, uint32_t frameCount)
{
    if (!synth || !left || !right || frameCount == 0) {
        return;
    }

    const double sampleRate = synth->sampleRate;
    const double twoPi = 2.0 * M_PI;
    const double gateTarget = atomic_load_explicit(&synth->targetGate, memory_order_relaxed);
    const double frequencyTarget = OtamatoneClampFrequency(
        atomic_load_explicit(&synth->targetFrequency, memory_order_relaxed));
    const double mouthTarget = ToyDSPClamp(
        atomic_load_explicit(&synth->targetMouth, memory_order_relaxed), 0.0, 1.0);

    if (gateTarget > 0.35 && synth->previousGateTarget <= 0.35) {
        synth->chiff = 1.0;
    }
    synth->previousGateTarget = gateTarget;

    for (uint32_t frame = 0; frame < frameCount; frame++) {
        double gateCoefficient = gateTarget > synth->gate ? synth->attackCoefficient
                                                          : synth->releaseCoefficient;
        synth->gate += (gateTarget - synth->gate) * gateCoefficient;
        synth->frequency += (frequencyTarget - synth->frequency) * synth->pitchCoefficient;
        synth->mouth += (mouthTarget - synth->mouth) * synth->mouthCoefficient;

        synth->vibratoPhase += 5.35 / sampleRate;
        if (synth->vibratoPhase >= 1.0) {
            synth->vibratoPhase -= 1.0;
        }
        synth->driftPhase += 0.17 / sampleRate;
        if (synth->driftPhase >= 1.0) {
            synth->driftPhase -= 1.0;
        }
        synth->jawPhase += 0.75 / sampleRate;
        if (synth->jawPhase >= 1.0) {
            synth->jawPhase -= 1.0;
        }

        double driftRandom = ToyNoiseBipolar(&synth->noiseState);
        synth->driftValue += (driftRandom - synth->driftValue) * synth->driftCoefficient;

        double vibratoDepth = 0.0026 + synth->mouth * 0.0074;
        double vibrato = sin(twoPi * synth->vibratoPhase) * vibratoDepth;
        double drift = sin(twoPi * synth->driftPhase) * 0.0016 + synth->driftValue * 0.0011;
        double jawWah = sin(twoPi * synth->jawPhase) * synth->mouth * 0.008;

        double modulatedFrequency = synth->frequency * (1.0 + vibrato + drift + jawWah);
        if (modulatedFrequency < 40.0) {
            modulatedFrequency = 40.0;
        }
        if (modulatedFrequency > sampleRate * 0.42) {
            modulatedFrequency = sampleRate * 0.42;
        }

        double dtA = modulatedFrequency / sampleRate;
        double dtB = dtA * 1.0037;
        synth->phaseA += dtA;
        if (synth->phaseA >= 1.0) {
            synth->phaseA -= 1.0;
        }
        synth->phaseB += dtB;
        if (synth->phaseB >= 1.0) {
            synth->phaseB -= 1.0;
        }

        double sawA = ToyBandlimitedSaw(synth->phaseA, dtA);
        double sawB = ToyBandlimitedSaw(synth->phaseB, dtB);
        double source = sawA * 0.58 + sawB * 0.42;

        double breath = ToyNoiseBipolar(&synth->noiseState);
        source += breath * (0.022 + synth->mouth * 0.028);
        source += breath * synth->chiff * 0.24;
        synth->chiff *= 0.9994;

        if (synth->filterUpdateCountdown == 0) {
            OtamatoneUpdateFilters(synth, synth->mouth);
            synth->filterUpdateCountdown = 24;
        }
        synth->filterUpdateCountdown--;

        double formantOne = ToyBiquadProcess(&synth->formantOne, source);
        double formantTwo = ToyBiquadProcess(&synth->formantTwo, source);
        double formantThree = ToyBiquadProcess(&synth->formantThree, source);
        double wah = ToyBiquadProcess(&synth->wah, source);

        double mixed = formantOne * 0.95
                     + formantTwo * 0.56
                     + formantThree * 0.23
                     + source * 0.16
                     + wah * 0.26;

        mixed = ToyBiquadProcess(&synth->nasal, mixed);
        mixed = ToySoftClip(mixed * 2.35);
        mixed = ToyBiquadProcess(&synth->lowpass, mixed);

        double dcOutput = mixed - synth->dcInput + 0.9975 * synth->dcOutput;
        synth->dcInput = mixed;
        synth->dcOutput = dcOutput;

        double amplitude = synth->gate * synth->gate * (3.0 - 2.0 * synth->gate);
        double output = dcOutput * amplitude * 0.31;
        output = ToySoftClip(output * 1.15) * 0.87;

        if (!isfinite(output)) {
            output = 0.0;
            ToyBiquadReset(&synth->formantOne);
            ToyBiquadReset(&synth->formantTwo);
            ToyBiquadReset(&synth->formantThree);
            ToyBiquadReset(&synth->nasal);
            ToyBiquadReset(&synth->wah);
            ToyBiquadReset(&synth->lowpass);
            synth->dcInput = 0.0;
            synth->dcOutput = 0.0;
        }

        left[frame] = (float)output;
        right[frame] = (float)output;
    }
}
