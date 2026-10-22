#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

static inline CGFloat ToyClamp(CGFloat value, CGFloat lower, CGFloat upper)
{
    return MIN(MAX(value, lower), upper);
}

static inline double ToyClampDouble(double value, double lower, double upper)
{
    return fmin(fmax(value, lower), upper);
}

static inline CGFloat ToySmoothstep(CGFloat edge0, CGFloat edge1, CGFloat value)
{
    CGFloat t = ToyClamp((value - edge0) / (edge1 - edge0), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

/// Creates a color from a 0xRRGGBB literal.
NSColor *ToyColor(uint32_t rgb, CGFloat alpha);

NSFont *ToyTitleFont(CGFloat size);
NSFont *ToyBodyFont(CGFloat size);
NSFont *ToySmallFont(CGFloat size);
NSFont *ToyMonoFont(CGFloat size, NSFontWeight weight);

/// Draws a single line of text at a bottom-left origin, optionally with tracking.
void ToyDrawText(NSString *text, NSPoint point, NSFont *font, NSColor *color, CGFloat tracking);
NSSize ToyTextSize(NSString *text, NSFont *font, CGFloat tracking);

/// A uniform scale + translation that fits a design-space rectangle inside a view.
typedef struct {
    CGFloat scale;
    CGFloat offsetX;
    CGFloat offsetY;
} ToyFit;

ToyFit ToyFitMake(NSRect bounds, CGFloat designWidth, CGFloat designHeight);
NSPoint ToyFitPoint(ToyFit fit, NSPoint point);

/// Convenience fills that clip to a path and paint a gradient.
void ToyFillVertical(NSBezierPath *path, NSColor *bottomColor, NSColor *topColor, NSRect rect);
void ToyFillRadial(NSBezierPath *path, NSColor *innerColor, NSColor *outerColor, NSPoint center,
                   CGFloat innerRadius, CGFloat outerRadius);

/// Soft elliptical contact shadow. Draw in the current (design) coordinate space.
void ToyDrawContactShadow(NSPoint center, CGFloat width, CGFloat height, CGFloat strength);

NS_ASSUME_NONNULL_END
