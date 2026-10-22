#import "ToyTheme.h"

NSColor *ToyColor(uint32_t rgb, CGFloat alpha)
{
    return [NSColor colorWithSRGBRed:((rgb >> 16) & 0xFF) / 255.0
                               green:((rgb >> 8) & 0xFF) / 255.0
                                blue:(rgb & 0xFF) / 255.0
                               alpha:alpha];
}

static NSFont *ToyNamedFont(NSString *name, CGFloat size)
{
    NSFont *font = [NSFont fontWithName:name size:size];
    if (font) {
        return font;
    }
    return [NSFont systemFontOfSize:size weight:NSFontWeightRegular];
}

NSFont *ToyTitleFont(CGFloat size)
{
    return ToyNamedFont(@"AvenirNext-DemiBold", size);
}

NSFont *ToyBodyFont(CGFloat size)
{
    return ToyNamedFont(@"AvenirNext-Medium", size);
}

NSFont *ToySmallFont(CGFloat size)
{
    return ToyNamedFont(@"AvenirNext-DemiBold", size);
}

NSFont *ToyMonoFont(CGFloat size, NSFontWeight weight)
{
    return [NSFont monospacedSystemFontOfSize:size weight:weight];
}

static NSDictionary *ToyTextAttributes(NSFont *font, NSColor *color, CGFloat tracking)
{
    return @{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: color,
        NSKernAttributeName: @(tracking)
    };
}

void ToyDrawText(NSString *text, NSPoint point, NSFont *font, NSColor *color, CGFloat tracking)
{
    [text drawAtPoint:point withAttributes:ToyTextAttributes(font, color, tracking)];
}

NSSize ToyTextSize(NSString *text, NSFont *font, CGFloat tracking)
{
    return [text sizeWithAttributes:ToyTextAttributes(font, NSColor.whiteColor, tracking)];
}

ToyFit ToyFitMake(NSRect bounds, CGFloat designWidth, CGFloat designHeight)
{
    CGFloat scale = MIN(NSWidth(bounds) / designWidth, NSHeight(bounds) / designHeight);
    if (!isfinite(scale) || scale <= 0.0) {
        scale = 1.0;
    }
    ToyFit fit;
    fit.scale = scale;
    fit.offsetX = NSMidX(bounds) - designWidth * scale * 0.5;
    fit.offsetY = NSMidY(bounds) - designHeight * scale * 0.5;
    return fit;
}

NSPoint ToyFitPoint(ToyFit fit, NSPoint point)
{
    return NSMakePoint((point.x - fit.offsetX) / fit.scale,
                       (point.y - fit.offsetY) / fit.scale);
}

void ToyFillVertical(NSBezierPath *path, NSColor *bottomColor, NSColor *topColor, NSRect rect)
{
    [NSGraphicsContext saveGraphicsState];
    [path addClip];
    NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:bottomColor endingColor:topColor];
    [gradient drawInRect:rect angle:90.0];
    [NSGraphicsContext restoreGraphicsState];
}

void ToyFillRadial(NSBezierPath *path, NSColor *innerColor, NSColor *outerColor, NSPoint center,
                   CGFloat innerRadius, CGFloat outerRadius)
{
    [NSGraphicsContext saveGraphicsState];
    [path addClip];
    NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:innerColor endingColor:outerColor];
    [gradient drawFromCenter:center radius:innerRadius toCenter:center radius:outerRadius options:0];
    [NSGraphicsContext restoreGraphicsState];
}

void ToyDrawContactShadow(NSPoint center, CGFloat width, CGFloat height, CGFloat strength)
{
    [NSGraphicsContext saveGraphicsState];
    NSRect ellipseRect = NSMakeRect(center.x - width * 0.5, center.y - height * 0.5, width, height);
    NSBezierPath *ellipse = [NSBezierPath bezierPathWithOvalInRect:ellipseRect];
    [ellipse addClip];
    NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:ToyColor(0x000000, 0.42 * strength)
                                                       endingColor:ToyColor(0x000000, 0.0)];
    [gradient drawFromCenter:center radius:0.0
                    toCenter:center radius:width * 0.5
                     options:NSGradientDrawsAfterEndingLocation];
    [NSGraphicsContext restoreGraphicsState];
}
