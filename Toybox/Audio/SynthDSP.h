#ifndef SynthDSP_h
#define SynthDSP_h

#include <math.h>
#include <stdint.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

/// A direct-form-II-transposed RBJ biquad.
typedef struct {
    double b0;
    double b1;
    double b2;
    double a1;
    double a2;
    double z1;
    double z2;
} ToyBiquad;

static inline void ToyBiquadReset(ToyBiquad *filter)
{
    filter->z1 = 0.0;
    filter->z2 = 0.0;
}

static inline double ToyBiquadProcess(ToyBiquad *filter, double input)
{
    double output = filter->b0 * input + filter->z1;
    filter->z1 = filter->b1 * input - filter->a1 * output + filter->z2;
    filter->z2 = filter->b2 * input - filter->a2 * output;
    return output;
}

static inline void ToyBiquadNormalize(ToyBiquad *filter, double a0, double b0, double b1, double b2,
                                      double a1, double a2)
{
    if (fabs(a0) < 1e-12) {
        a0 = 1e-12;
    }
    filter->b0 = b0 / a0;
    filter->b1 = b1 / a0;
    filter->b2 = b2 / a0;
    filter->a1 = a1 / a0;
    filter->a2 = a2 / a0;
}

static inline double ToySanitizeCutoff(double frequency, double sampleRate)
{
    double nyquist = sampleRate * 0.5;
    return fmin(fmax(frequency, 15.0), nyquist * 0.94);
}

static inline void ToyBiquadSetLowpass(ToyBiquad *filter, double sampleRate, double frequency, double q)
{
    double w0 = 2.0 * M_PI * ToySanitizeCutoff(frequency, sampleRate) / sampleRate;
    double cosw = cos(w0);
    double alpha = sin(w0) / (2.0 * fmax(q, 0.05));
    double b1 = 1.0 - cosw;
    double b0 = b1 * 0.5;
    ToyBiquadNormalize(filter, 1.0 + alpha, b0, b1, b0, -2.0 * cosw, 1.0 - alpha);
}

static inline void ToyBiquadSetHighpass(ToyBiquad *filter, double sampleRate, double frequency, double q)
{
    double w0 = 2.0 * M_PI * ToySanitizeCutoff(frequency, sampleRate) / sampleRate;
    double cosw = cos(w0);
    double alpha = sin(w0) / (2.0 * fmax(q, 0.05));
    double b0 = (1.0 + cosw) * 0.5;
    ToyBiquadNormalize(filter, 1.0 + alpha, b0, -(1.0 + cosw), b0, -2.0 * cosw, 1.0 - alpha);
}

static inline void ToyBiquadSetBandpass(ToyBiquad *filter, double sampleRate, double frequency, double q)
{
    double w0 = 2.0 * M_PI * ToySanitizeCutoff(frequency, sampleRate) / sampleRate;
    double cosw = cos(w0);
    double alpha = sin(w0) / (2.0 * fmax(q, 0.05));
    ToyBiquadNormalize(filter, 1.0 + alpha, alpha, 0.0, -alpha, -2.0 * cosw, 1.0 - alpha);
}

static inline void ToyBiquadSetPeaking(ToyBiquad *filter, double sampleRate, double frequency,
                                       double q, double gainDB)
{
    double w0 = 2.0 * M_PI * ToySanitizeCutoff(frequency, sampleRate) / sampleRate;
    double cosw = cos(w0);
    double alpha = sin(w0) / (2.0 * fmax(q, 0.05));
    double a = pow(10.0, gainDB / 40.0);
    ToyBiquadNormalize(filter,
                       1.0 + alpha / a,
                       1.0 + alpha * a,
                       -2.0 * cosw,
                       1.0 - alpha * a,
                       -2.0 * cosw,
                       1.0 - alpha / a);
}

static inline uint32_t ToyNextRandom(uint32_t *state)
{
    uint32_t x = *state;
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    *state = x ? x : 0x6D2B79F5u;
    return *state;
}

static inline double ToyRandomUnit(uint32_t *state)
{
    return (double)ToyNextRandom(state) / 4294967295.0;
}

static inline double ToyNoiseBipolar(uint32_t *state)
{
    return ToyRandomUnit(state) * 2.0 - 1.0;
}

static inline double ToyOnePoleCoefficient(double seconds, double sampleRate)
{
    double safeSeconds = fmax(seconds, 0.00005);
    return 1.0 - exp(-1.0 / (safeSeconds * sampleRate));
}

static inline double ToyDSPClamp(double value, double lower, double upper)
{
    return fmin(fmax(value, lower), upper);
}

static inline double ToySmoothstepDouble(double edge0, double edge1, double value)
{
    double t = fmin(fmax((value - edge0) / (edge1 - edge0), 0.0), 1.0);
    return t * t * (3.0 - 2.0 * t);
}

/// PolyBLEP residual for a unit-phase oscillator with step dt.
static inline double ToyPolyBlep(double phase, double dt)
{
    if (dt <= 0.0) {
        return 0.0;
    }
    if (phase < dt) {
        double t = phase / dt;
        return t + t - t * t - 1.0;
    }
    if (phase > 1.0 - dt) {
        double t = (phase - 1.0) / dt;
        return t * t + t + t + 1.0;
    }
    return 0.0;
}

static inline double ToyBandlimitedSaw(double phase, double dt)
{
    return 2.0 * phase - 1.0 - ToyPolyBlep(phase, dt);
}

static inline double ToyBandlimitedPulse(double phase, double pulseWidth, double dt)
{
    double width = fmin(fmax(pulseWidth, 0.05), 0.95);
    double value = phase < width ? 1.0 : -1.0;
    value += ToyPolyBlep(phase, dt);
    double fallingPhase = phase + (1.0 - width);
    if (fallingPhase >= 1.0) {
        fallingPhase -= 1.0;
    }
    value -= ToyPolyBlep(fallingPhase, dt);
    return value;
}

static inline double ToySoftClip(double value)
{
    return tanh(value);
}

#endif /* SynthDSP_h */
