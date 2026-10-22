#import "ChickenView.h"

#import "ToyAudioEngine.h"
#import "ToyMusic.h"
#import "ToyTheme.h"
#import <QuartzCore/QuartzCore.h>
#include <stdlib.h>
#include <string.h>

static const CGFloat kChickenDesignWidth = 460.0;
static const CGFloat kChickenDesignHeight = 660.0;

static NSColor *ChickenYellowTop(void) { return ToyColor(0xFFE45C, 1.0); }
static NSColor *ChickenYellowBottom(void) { return ToyColor(0xF0C126, 1.0); }
static NSColor *ChickenRedTop(void) { return ToyColor(0xF24A3F, 1.0); }
static NSColor *ChickenRedBottom(void) { return ToyColor(0xBE1C23, 1.0); }

typedef struct {
    CGFloat squeeze;
    CGFloat cx;
    CGFloat bodyBottom;
    CGFloat bodyTop;
    CGFloat bodyWidth;
    CGFloat bodyHeight;
    CGFloat bodyCY;
    CGFloat neckBaseY;
    CGFloat neckWidthBase;
    CGFloat neckWidthTop;
    CGFloat headCX;
    CGFloat headCY;
    CGFloat headRX;
    CGFloat headRY;
    CGFloat beakOpen;
    CGFloat eyeBulge;
    CGFloat wingFlare;
    CGFloat jitterX;
    CGFloat jitterY;
} ChickenGeometry;

typedef struct {
    CGFloat u;
    CGFloat v;
    CGFloat radius;
    CGFloat alpha;
} ChickenPore;

static ChickenPore gChickenPores[112];
static dispatch_once_t gChickenPoresOnce;

static ChickenGeometry ChickenGeometryMake(CGFloat squeeze, NSTimeInterval time)
{
    ChickenGeometry g;
    memset(&g, 0, sizeof(g));
    g.squeeze = ToyClamp(squeeze, 0.0, 1.0);
    g.cx = 230.0;
    g.bodyBottom = 92.0;
    g.bodyWidth = 236.0 * (1.0 + 0.045 * g.squeeze);
    g.bodyHeight = 248.0 * (1.0 - 0.155 * g.squeeze);
    g.bodyTop = g.bodyBottom + g.bodyHeight;
    g.bodyCY = (g.bodyBottom + g.bodyTop) * 0.5;
    g.neckBaseY = g.bodyTop - 20.0;
    g.neckWidthBase = 58.0 + 4.0 * g.squeeze;
    g.neckWidthTop = 42.0;
    g.jitterX = sin(time * 46.0) * 2.3 * g.squeeze;
    g.jitterY = cos(time * 33.0) * 1.2 * g.squeeze;

    CGFloat neckLength = 182.0 * (1.0 + 0.18 * g.squeeze);
    g.headCX = g.cx + g.jitterX * 0.72;
    g.headCY = g.neckBaseY + neckLength + 6.0 * g.squeeze + g.jitterY;
    g.headRX = 47.0 * (1.0 + 0.018 * g.squeeze);
    g.headRY = 49.0 * (1.0 - 0.012 * g.squeeze);
    g.beakOpen = 25.0 * ToySmoothstep(0.0, 0.72, g.squeeze);
    g.eyeBulge = 1.0 + 0.11 * g.squeeze;
    g.wingFlare = 7.0 * g.squeeze;
    return g;
}

static NSBezierPath *ChickenBodyPath(ChickenGeometry g)
{
    CGFloat w = g.bodyWidth;
    CGFloat h = g.bodyHeight;
    CGFloat cx = g.cx;
    CGFloat bottom = g.bodyBottom;
    CGFloat top = g.bodyTop;

    NSBezierPath *path = [NSBezierPath bezierPath];
    [path moveToPoint:NSMakePoint(cx, top)];
    [path curveToPoint:NSMakePoint(cx + w * 0.475, bottom + h * 0.56)
          controlPoint1:NSMakePoint(cx + w * 0.21, top)
          controlPoint2:NSMakePoint(cx + w * 0.475, top - h * 0.17)];
    [path curveToPoint:NSMakePoint(cx + w * 0.30, bottom + 9.0)
          controlPoint1:NSMakePoint(cx + w * 0.49, bottom + h * 0.28)
          controlPoint2:NSMakePoint(cx + w * 0.44, bottom + 9.0)];
    [path curveToPoint:NSMakePoint(cx, bottom)
          controlPoint1:NSMakePoint(cx + w * 0.16, bottom)
          controlPoint2:NSMakePoint(cx + w * 0.07, bottom)];
    [path curveToPoint:NSMakePoint(cx - w * 0.30, bottom + 9.0)
          controlPoint1:NSMakePoint(cx - w * 0.07, bottom)
          controlPoint2:NSMakePoint(cx - w * 0.16, bottom)];
    [path curveToPoint:NSMakePoint(cx - w * 0.475, bottom + h * 0.56)
          controlPoint1:NSMakePoint(cx - w * 0.44, bottom + 9.0)
          controlPoint2:NSMakePoint(cx - w * 0.49, bottom + h * 0.28)];
    [path curveToPoint:NSMakePoint(cx, top)
          controlPoint1:NSMakePoint(cx - w * 0.475, top - h * 0.17)
          controlPoint2:NSMakePoint(cx - w * 0.21, top)];
    [path closePath];
    return path;
}

static NSBezierPath *ChickenNeckPath(ChickenGeometry g)
{
    CGFloat baseHalf = g.neckWidthBase * 0.5;
    CGFloat topHalf = g.neckWidthTop * 0.5;
    CGFloat baseY = g.neckBaseY - 12.0;
    CGFloat topY = g.headCY - 4.0;
    CGFloat headShift = g.jitterX * 0.45;
    CGFloat midY = baseY + (topY - baseY) * 0.52;

    NSBezierPath *path = [NSBezierPath bezierPath];
    [path moveToPoint:NSMakePoint(g.cx - baseHalf, baseY)];
    [path curveToPoint:NSMakePoint(g.cx - topHalf + headShift, topY)
          controlPoint1:NSMakePoint(g.cx - baseHalf - 3.0, midY)
          controlPoint2:NSMakePoint(g.cx - topHalf - 1.0 + headShift * 0.7, topY - 44.0)];
    [path curveToPoint:NSMakePoint(g.cx + topHalf + headShift, topY)
          controlPoint1:NSMakePoint(g.cx - topHalf * 0.4 + headShift, topY + 8.0)
          controlPoint2:NSMakePoint(g.cx + topHalf * 0.4 + headShift, topY + 8.0)];
    [path curveToPoint:NSMakePoint(g.cx + baseHalf, baseY)
          controlPoint1:NSMakePoint(g.cx + topHalf + 1.0 + headShift * 0.7, topY - 44.0)
          controlPoint2:NSMakePoint(g.cx + baseHalf + 3.0, midY)];
    [path closePath];
    return path;
}

static NSBezierPath *ChickenWingPath(ChickenGeometry g, BOOL leftSide)
{
    CGFloat side = leftSide ? -1.0 : 1.0;
    CGFloat w = g.bodyWidth;
    CGFloat h = g.bodyHeight;
    CGFloat cx = g.cx;
    CGFloat cy = g.bodyCY;
    CGFloat flare = g.wingFlare;

    CGFloat topX = cx + side * (w * 0.305);
    CGFloat topY = cy + h * 0.285;
    CGFloat outerX = cx + side * (w * 0.545 + flare);
    CGFloat midY = cy + h * 0.055;
    CGFloat bottomX = cx + side * (w * 0.30);
    CGFloat bottomY = cy - h * 0.235;
    CGFloat innerX = cx + side * (w * 0.17);

    NSBezierPath *path = [NSBezierPath bezierPath];
    [path moveToPoint:NSMakePoint(topX, topY)];
    [path curveToPoint:NSMakePoint(outerX, midY)
          controlPoint1:NSMakePoint(topX + side * w * 0.13, topY)
          controlPoint2:NSMakePoint(outerX, midY + h * 0.13)];
    [path curveToPoint:NSMakePoint(bottomX, bottomY)
          controlPoint1:NSMakePoint(outerX, midY - h * 0.14)
          controlPoint2:NSMakePoint(bottomX + side * w * 0.10, bottomY)];
    [path curveToPoint:NSMakePoint(innerX, cy - h * 0.04)
          controlPoint1:NSMakePoint(bottomX - side * w * 0.06, bottomY)
          controlPoint2:NSMakePoint(innerX, bottomY + h * 0.08)];
    [path curveToPoint:NSMakePoint(topX, topY)
          controlPoint1:NSMakePoint(innerX, cy + h * 0.18)
          controlPoint2:NSMakePoint(topX - side * w * 0.05, topY - h * 0.06)];
    [path closePath];
    return path;
}

static NSBezierPath *ChickenCombPath(ChickenGeometry g)
{
    CGFloat x = g.headCX;
    CGFloat top = g.headCY + g.headRY - 4.0;
    NSBezierPath *path = [NSBezierPath bezierPath];
    [path moveToPoint:NSMakePoint(x - 31.0, top - 4.0)];
    [path curveToPoint:NSMakePoint(x - 37.0, top + 27.0)
          controlPoint1:NSMakePoint(x - 44.0, top + 1.0)
          controlPoint2:NSMakePoint(x - 45.0, top + 22.0)];
    [path curveToPoint:NSMakePoint(x - 18.0, top + 13.0)
          controlPoint1:NSMakePoint(x - 31.0, top + 34.0)
          controlPoint2:NSMakePoint(x - 23.0, top + 20.0)];
    [path curveToPoint:NSMakePoint(x - 5.0, top + 35.0)
          controlPoint1:NSMakePoint(x - 16.0, top + 22.0)
          controlPoint2:NSMakePoint(x - 11.0, top + 36.0)];
    [path curveToPoint:NSMakePoint(x + 11.0, top + 14.0)
          controlPoint1:NSMakePoint(x + 4.0, top + 38.0)
          controlPoint2:NSMakePoint(x + 7.0, top + 20.0)];
    [path curveToPoint:NSMakePoint(x + 30.0, top + 24.0)
          controlPoint1:NSMakePoint(x + 17.0, top + 19.0)
          controlPoint2:NSMakePoint(x + 25.0, top + 30.0)];
    [path curveToPoint:NSMakePoint(x + 33.0, top - 5.0)
          controlPoint1:NSMakePoint(x + 39.0, top + 18.0)
          controlPoint2:NSMakePoint(x + 41.0, top - 1.0)];
    [path curveToPoint:NSMakePoint(x - 31.0, top - 4.0)
          controlPoint1:NSMakePoint(x + 12.0, top + 7.0)
          controlPoint2:NSMakePoint(x - 12.0, top + 7.0)];
    [path closePath];
    return path;
}

static NSBezierPath *ChickenWattlePath(ChickenGeometry g, BOOL leftSide)
{
    CGFloat side = leftSide ? -1.0 : 1.0;
    CGFloat x = g.headCX + side * 11.0;
    CGFloat top = g.headCY - g.headRY * 0.58 - g.beakOpen * 0.55;
    CGFloat width = 14.0;
    CGFloat length = 24.0 + g.squeeze * 5.0;

    NSBezierPath *path = [NSBezierPath bezierPath];
    [path moveToPoint:NSMakePoint(x - width * 0.5, top)];
    [path curveToPoint:NSMakePoint(x - width * 0.62, top - length * 0.65)
          controlPoint1:NSMakePoint(x - width * 0.9, top - length * 0.2)
          controlPoint2:NSMakePoint(x - width * 0.9, top - length * 0.5)];
    [path curveToPoint:NSMakePoint(x, top - length)
          controlPoint1:NSMakePoint(x - width * 0.45, top - length * 0.9)
          controlPoint2:NSMakePoint(x - width * 0.16, top - length)];
    [path curveToPoint:NSMakePoint(x + width * 0.62, top - length * 0.65)
          controlPoint1:NSMakePoint(x + width * 0.25, top - length)
          controlPoint2:NSMakePoint(x + width * 0.9, top - length * 0.9)];
    [path curveToPoint:NSMakePoint(x + width * 0.5, top)
          controlPoint1:NSMakePoint(x + width * 0.85, top - length * 0.45)
          controlPoint2:NSMakePoint(x + width * 0.8, top - length * 0.16)];
    [path closePath];
    return path;
}

static void ChickenSpringStep(CGFloat *value, CGFloat *velocity, CGFloat target,
                              CGFloat stiffness, CGFloat damping, CGFloat dt)
{
    CGFloat acceleration = (target - *value) * stiffness - *velocity * damping;
    *velocity += acceleration * dt;
    *value += *velocity * dt;
    if (fabs(target - *value) < 0.0005 && fabs(*velocity) < 0.0015) {
        *value = target;
        *velocity = 0.0;
    }
}

static void ChickenDrawStroke(NSBezierPath *path, CGFloat width, NSColor *color)
{
    path.lineWidth = width;
    path.lineCapStyle = NSLineCapStyleRound;
    path.lineJoinStyle = NSLineJoinStyleRound;
    [color setStroke];
    [path stroke];
}

@interface ChickenView ()
@property (nonatomic, strong) ToyAudioEngine *audioEngine;
@end

@implementation ChickenView {
    NSTimer *_animationTimer;
    NSTimeInterval _lastTickTime;
    NSTimeInterval _squawkTriggerTime;
    BOOL _pressing;
    BOOL _squawkNoteReady;
    CGFloat _squeezeValue;
    CGFloat _squeezeVelocity;
    CGFloat _squeezeTarget;
    double _squawkFrequency;
}

- (instancetype)initWithAudioEngine:(ToyAudioEngine *)audioEngine
{
    self = [super initWithFrame:NSZeroRect];
    if (self) {
        _audioEngine = audioEngine;
        [self setAccessibilityElement:YES];
        [self setAccessibilityRole:NSAccessibilityGroupRole];
        [self setAccessibilityLabel:@"Rubber chicken"];
        [self setAccessibilityHelp:@"Press and hold to squeeze the chicken. Every squeeze plays a random note from the A minor pentatonic scale."];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidResignActive:)
                                                     name:NSApplicationDidResignActiveNotification
                                                   object:NSApp];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_animationTimer invalidate];
    [_audioEngine setChickenSqueeze:0.0];
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event
{
    (void)event;
    return YES;
}

- (BOOL)isOpaque
{
    return NO;
}

- (void)viewDidMoveToWindow
{
    [super viewDidMoveToWindow];
    if (self.window) {
        [self startAnimationTimer];
    }
}

- (void)viewWillMoveToWindow:(NSWindow *)newWindow
{
    [super viewWillMoveToWindow:newWindow];
    if (!newWindow) {
        [self cancelInteraction];
        [self stopAnimationTimer];
    }
}

- (void)resetCursorRects
{
    [super resetCursorRects];
    ToyFit fit = ToyFitMake(self.bounds, kChickenDesignWidth, kChickenDesignHeight);
    NSRect toyRect = NSMakeRect(92.0, 38.0, 280.0, 596.0);
    toyRect.origin.x = fit.offsetX + toyRect.origin.x * fit.scale;
    toyRect.origin.y = fit.offsetY + toyRect.origin.y * fit.scale;
    toyRect.size.width *= fit.scale;
    toyRect.size.height *= fit.scale;
    [self addCursorRect:toyRect cursor:NSCursor.pointingHandCursor];
}

- (void)startAnimationTimer
{
    if (_animationTimer) {
        return;
    }
    _lastTickTime = CACurrentMediaTime();
    __weak typeof(self) weakSelf = self;
    NSTimer *timer = [NSTimer timerWithTimeInterval:1.0 / 60.0
                                           repeats:YES
                                             block:^(NSTimer *unusedTimer) {
        [weakSelf animationTick];
    }];
    _animationTimer = timer;
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
}

- (void)stopAnimationTimer
{
    [_animationTimer invalidate];
    _animationTimer = nil;
}

- (void)applicationDidResignActive:(NSNotification *)notification
{
    (void)notification;
    [self cancelInteraction];
}

- (ToyFit)currentFit
{
    return ToyFitMake(self.bounds, kChickenDesignWidth, kChickenDesignHeight);
}

- (NSPoint)designPointForEvent:(NSEvent *)event
{
    NSPoint viewPoint = [self convertPoint:event.locationInWindow fromView:nil];
    return ToyFitPoint([self currentFit], viewPoint);
}

- (BOOL)toyContainsDesignPoint:(NSPoint)point
{
    ChickenGeometry g = ChickenGeometryMake(MAX(_squeezeValue, 0.0), CACurrentMediaTime());
    if ([ChickenBodyPath(g) containsPoint:point]) {
        return YES;
    }
    if (NSMouseInRect(point, NSMakeRect(g.cx - 40.0, g.neckBaseY - 8.0,
                                       80.0, g.headCY - g.neckBaseY + 30.0), NO)) {
        return YES;
    }
    NSRect headRect = NSMakeRect(g.headCX - g.headRX, g.headCY - g.headRY,
                                 g.headRX * 2.0, g.headRY * 2.0);
    return NSMouseInRect(point, headRect, NO);
}

- (void)beginSqueeze
{
    _pressing = YES;
    _squeezeTarget = 0.94;
    _squeezeValue = MAX(_squeezeValue, 0.42);
    _squeezeVelocity += 6.0;
    _squawkFrequency = 0.0;
    _squawkNoteReady = NO;
    _squawkTriggerTime = CACurrentMediaTime();
    [_audioEngine setChickenSqueeze:0.78];
    [_audioEngine triggerChicken];
    [self setNeedsDisplay:YES];
}

- (void)endSqueeze
{
    if (!_pressing) {
        return;
    }
    _pressing = NO;
    _squeezeTarget = 0.0;
    [self setNeedsDisplay:YES];
}

- (void)cancelInteraction
{
    [self endSqueeze];
    [_audioEngine setChickenSqueeze:0.0];
}

- (void)mouseDown:(NSEvent *)event
{
    NSPoint point = [self designPointForEvent:event];
    if (![self toyContainsDesignPoint:point]) {
        [super mouseDown:event];
        return;
    }
    [self beginSqueeze];
}

- (void)mouseDragged:(NSEvent *)event
{
    if (!_pressing) {
        [super mouseDragged:event];
    }
}

- (void)mouseUp:(NSEvent *)event
{
    [self endSqueeze];
    [super mouseUp:event];
}

- (void)animationTick
{
    NSTimeInterval now = CACurrentMediaTime();
    CGFloat dt = (CGFloat)(now - _lastTickTime);
    _lastTickTime = now;
    if (dt <= 0.0 || dt > 0.05) {
        dt = 1.0 / 60.0;
    }

    CGFloat previous = _squeezeValue;
    ChickenSpringStep(&_squeezeValue, &_squeezeVelocity, _squeezeTarget, 285.0, 17.5, dt);
    if (_squeezeValue < -0.04) {
        _squeezeValue = -0.04;
        _squeezeVelocity *= -0.35;
    }

    [_audioEngine setChickenSqueeze:ToyClampDouble(_squeezeValue, 0.0, 1.0)];

    BOOL noteChanged = NO;
    if (_pressing && !_squawkNoteReady && now - _squawkTriggerTime > 0.03) {
        double frequency = [_audioEngine chickenFrequency];
        if (frequency > 0.0) {
            _squawkFrequency = frequency;
            _squawkNoteReady = YES;
            noteChanged = YES;
        }
    }

    BOOL moving = fabs(_squeezeValue - previous) > 0.0002 || fabs(_squeezeVelocity) > 0.001;
    if (_pressing || moving || noteChanged) {
        [self setNeedsDisplay:YES];
    }
}

- (void)drawRect:(NSRect)dirtyRect
{
    (void)dirtyRect;
    [super drawRect:dirtyRect];

    CGContextRef context = NSGraphicsContext.currentContext.CGContext;
    ToyFit fit = [self currentFit];
    NSTimeInterval now = CACurrentMediaTime();
    ChickenGeometry g = ChickenGeometryMake(MAX(_squeezeValue, 0.0), now);

    CGContextSaveGState(context);
    CGContextTranslateCTM(context, fit.offsetX, fit.offsetY);
    CGContextScaleCTM(context, fit.scale, fit.scale);

    [self drawHaloWithGeometry:g time:now];

    ToyDrawContactShadow(NSMakePoint(g.cx, 53.0), g.bodyWidth * 0.95, 34.0, 1.0);

    [self drawLegsWithGeometry:g];
    [self drawNeckWithGeometry:g];
    [self drawBodyWithGeometry:g];
    [self drawWingsWithGeometry:g];
    [self drawBowTieWithGeometry:g];
    [self drawCombWithGeometry:g];
    [self drawHeadWithGeometry:g];
    [self drawFaceWithGeometry:g];
    [self drawSquawkScaleWithGeometry:g];
    [self drawNoteTagWithGeometry:g];

    CGContextRestoreGState(context);
}

- (void)drawHaloWithGeometry:(ChickenGeometry)g time:(NSTimeInterval)now
{
    CGFloat presence = g.squeeze;
    if (presence < 0.015) {
        return;
    }
    CGFloat pulse = 0.9 + 0.1 * sin(now * 2.6);
    NSColor *inner = ToyColor(0xFFD468, 0.085 * presence * pulse);
    NSColor *outer = ToyColor(0xFFD468, 0.0);
    [NSGraphicsContext saveGraphicsState];
    NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:inner endingColor:outer];
    [gradient drawFromCenter:NSMakePoint(g.cx, g.bodyCY + 40.0) radius:10.0
                    toCenter:NSMakePoint(g.cx, g.bodyCY + 40.0) radius:290.0
                     options:NSGradientDrawsAfterEndingLocation];
    [NSGraphicsContext restoreGraphicsState];
}

- (void)drawLegsWithGeometry:(ChickenGeometry)g
{
    CGFloat topY = g.bodyBottom + 30.0;
    for (NSInteger sideIndex = -1; sideIndex <= 1; sideIndex += 2) {
        CGFloat side = (CGFloat)sideIndex;
        CGFloat legTopX = g.cx + side * 36.0;
        CGFloat ankleX = g.cx + side * 40.0;
        CGFloat ankleY = 58.0;

        NSBezierPath *leg = [NSBezierPath bezierPath];
        [leg moveToPoint:NSMakePoint(legTopX, topY)];
        [leg curveToPoint:NSMakePoint(ankleX, ankleY)
            controlPoint1:NSMakePoint(legTopX + side * 5.0, topY - 30.0)
            controlPoint2:NSMakePoint(ankleX - side * 2.0, ankleY + 26.0)];
        ChickenDrawStroke(leg, 12.0, ToyColor(0xA83A16, 1.0));
        ChickenDrawStroke(leg, 8.2, ToyColor(0xE25C2C, 1.0));

        NSBezierPath *legLight = [NSBezierPath bezierPath];
        [legLight moveToPoint:NSMakePoint(legTopX - 2.0, topY - 8.0)];
        [legLight curveToPoint:NSMakePoint(ankleX - 2.0, ankleY + 10.0)
                 controlPoint1:NSMakePoint(legTopX + side * 2.0 - 2.0, topY - 30.0)
                 controlPoint2:NSMakePoint(ankleX - 2.0, ankleY + 26.0)];
        ChickenDrawStroke(legLight, 2.0, ToyColor(0xFF9A60, 0.75));

        for (NSInteger toe = -1; toe <= 1; toe++) {
            CGFloat toeX = ankleX + side * 0.0 + toe * 15.0;
            CGFloat toeY = 42.0 + fabs((CGFloat)toe) * 1.5;
            NSBezierPath *toePath = [NSBezierPath bezierPath];
            [toePath moveToPoint:NSMakePoint(ankleX, ankleY + 2.0)];
            [toePath curveToPoint:NSMakePoint(toeX, toeY)
                    controlPoint1:NSMakePoint(ankleX + toe * 2.0, ankleY - 8.0)
                    controlPoint2:NSMakePoint(toeX - toe * 1.5, toeY + 9.0)];
            ChickenDrawStroke(toePath, 9.0, ToyColor(0xA83A16, 1.0));
            ChickenDrawStroke(toePath, 6.0, ToyColor(0xDE552A, 1.0));
            ChickenDrawStroke(toePath, 1.4, ToyColor(0xFF9D69, 0.65));
        }
    }
}

- (void)drawNeckWithGeometry:(ChickenGeometry)g
{
    NSBezierPath *neck = ChickenNeckPath(g);
    ToyFillVertical(neck, ChickenYellowBottom(), ChickenYellowTop(),
                    NSMakeRect(0.0, 0.0, kChickenDesignWidth, kChickenDesignHeight));

    [NSGraphicsContext saveGraphicsState];
    [neck addClip];

    NSBezierPath *lightEdge = [NSBezierPath bezierPath];
    [lightEdge moveToPoint:NSMakePoint(g.cx - 20.0, g.neckBaseY + 6.0)];
    [lightEdge curveToPoint:NSMakePoint(g.cx - 15.0 + g.jitterX * 0.3, g.headCY - 22.0)
               controlPoint1:NSMakePoint(g.cx - 24.0, g.neckBaseY + 80.0)
               controlPoint2:NSMakePoint(g.cx - 20.0 + g.jitterX * 0.3, g.headCY - 90.0)];
    ChickenDrawStroke(lightEdge, 4.2, ToyColor(0xFFF2A1, 0.30));

    NSGradient *rightShade = [[NSGradient alloc] initWithStartingColor:ToyColor(0xD7A20E, 0.0)
                                                          endingColor:ToyColor(0xD7A20E, 0.30)];
    [rightShade drawInRect:NSMakeRect(g.cx + 4.0, g.neckBaseY, g.neckWidthBase * 0.55,
                                      g.headCY - g.neckBaseY)
                     angle:0.0];
    [NSGraphicsContext restoreGraphicsState];

    neck.lineWidth = 1.1;
    [ToyColor(0xC28E0C, 0.35) setStroke];
    [neck stroke];
}

- (void)drawBodyWithGeometry:(ChickenGeometry)g
{
    NSBezierPath *body = ChickenBodyPath(g);
    ToyFillVertical(body, ChickenYellowBottom(), ChickenYellowTop(),
                    NSMakeRect(0.0, 0.0, kChickenDesignWidth, kChickenDesignHeight));

    [NSGraphicsContext saveGraphicsState];
    [body addClip];

    // Rubber pores, deterministic so they do not crawl.
    dispatch_once(&gChickenPoresOnce, ^{
        uint32_t seed = 0x91E10DA5u;
        for (NSInteger index = 0; index < 112; index++) {
            CGFloat u;
            CGFloat v;
            do {
                seed = seed * 1664525u + 1013904223u;
                u = ((seed >> 8) / 16777215.0) * 2.0 - 1.0;
                seed = seed * 1664525u + 1013904223u;
                v = ((seed >> 8) / 16777215.0) * 2.0 - 1.0;
            } while (u * u + v * v > 0.93);
            gChickenPores[index].u = u;
            gChickenPores[index].v = v;
            gChickenPores[index].radius = 0.65 + ((seed >> 4) & 0xFF) / 255.0 * 0.95;
            gChickenPores[index].alpha = 0.06 + ((seed >> 12) & 0x7F) / 127.0 * 0.10;
        }
    });

    [ToyColor(0xFFF6B5, 1.0) setFill];
    for (NSInteger index = 0; index < 112; index++) {
        ChickenPore pore = gChickenPores[index];
        CGFloat x = g.cx + pore.u * g.bodyWidth * 0.46;
        CGFloat y = g.bodyCY + pore.v * g.bodyHeight * 0.46;
        NSRect poreRect = NSMakeRect(x - pore.radius, y - pore.radius,
                                     pore.radius * 2.0, pore.radius * 2.0);
        NSBezierPath *dot = [NSBezierPath bezierPathWithOvalInRect:poreRect];
        [[ToyColor(0xFFF4AD, pore.alpha) colorWithAlphaComponent:pore.alpha] setFill];
        [dot fill];
    }

    // Volume shading.
    NSGradient *lowerShade = [[NSGradient alloc] initWithStartingColor:ToyColor(0xC9970C, 0.23)
                                                          endingColor:ToyColor(0xC9970C, 0.0)];
    [lowerShade drawInRect:NSMakeRect(g.cx - g.bodyWidth * 0.55, g.bodyBottom,
                                      g.bodyWidth * 1.1, g.bodyHeight * 0.62)
                     angle:90.0];

    NSBezierPath *bellyLight = [NSBezierPath bezierPathWithOvalInRect:
        NSMakeRect(g.cx - g.bodyWidth * 0.30,
                   g.bodyCY + g.bodyHeight * 0.02,
                   g.bodyWidth * 0.46,
                   g.bodyHeight * 0.38)];
    ToyFillRadial(bellyLight, ToyColor(0xFFFFFF, 0.20), ToyColor(0xFFFFFF, 0.0),
                  NSMakePoint(g.cx - g.bodyWidth * 0.08, g.bodyCY + g.bodyHeight * 0.22),
                  2.0, g.bodyWidth * 0.35);

    NSGradient *neckShadow = [[NSGradient alloc] initWithStartingColor:ToyColor(0xC7910A, 0.24)
                                                          endingColor:ToyColor(0xC7910A, 0.0)];
    [neckShadow drawInRect:NSMakeRect(g.cx - g.bodyWidth * 0.3, g.bodyTop - 46.0,
                                      g.bodyWidth * 0.6, 56.0)
                     angle:90.0];
    [NSGraphicsContext restoreGraphicsState];

    body.lineWidth = 1.4;
    [ToyColor(0xC5910C, 0.42) setStroke];
    [body stroke];

    NSBezierPath *specular = [NSBezierPath bezierPathWithOvalInRect:
        NSMakeRect(g.cx - g.bodyWidth * 0.38, g.bodyCY + g.bodyHeight * 0.18,
                   g.bodyWidth * 0.30, g.bodyHeight * 0.17)];
    ToyFillRadial(specular, ToyColor(0xFFFFFF, 0.20), ToyColor(0xFFFFFF, 0.0),
                  NSMakePoint(g.cx - g.bodyWidth * 0.26, g.bodyCY + g.bodyHeight * 0.28),
                  1.0, 40.0);
}

- (void)drawWingsWithGeometry:(ChickenGeometry)g
{
    for (NSInteger sideIndex = 0; sideIndex <= 1; sideIndex++) {
        BOOL left = sideIndex == 0;
        NSBezierPath *wing = ChickenWingPath(g, left);
        ToyFillVertical(wing, ToyColor(0xECBA1F, 1.0), ToyColor(0xFFE36A, 1.0),
                        NSMakeRect(0.0, 0.0, kChickenDesignWidth, kChickenDesignHeight));

        [NSGraphicsContext saveGraphicsState];
        [wing addClip];
        CGFloat side = left ? -1.0 : 1.0;
        NSBezierPath *wingLight = [NSBezierPath bezierPath];
        [wingLight moveToPoint:NSMakePoint(g.cx + side * g.bodyWidth * 0.34,
                                           g.bodyCY + g.bodyHeight * 0.22)];
        [wingLight curveToPoint:NSMakePoint(g.cx + side * g.bodyWidth * 0.46,
                                            g.bodyCY - g.bodyHeight * 0.10)
                   controlPoint1:NSMakePoint(g.cx + side * g.bodyWidth * 0.43,
                                             g.bodyCY + g.bodyHeight * 0.08)
                   controlPoint2:NSMakePoint(g.cx + side * g.bodyWidth * 0.48,
                                             g.bodyCY - g.bodyHeight * 0.02)];
        ChickenDrawStroke(wingLight, 4.5, ToyColor(0xFFF4A0, 0.28));

        NSBezierPath *crease = [NSBezierPath bezierPath];
        [crease moveToPoint:NSMakePoint(g.cx + side * g.bodyWidth * 0.35, g.bodyCY + g.bodyHeight * 0.20)];
        [crease curveToPoint:NSMakePoint(g.cx + side * g.bodyWidth * 0.30,
                                         g.bodyCY - g.bodyHeight * 0.16)
              controlPoint1:NSMakePoint(g.cx + side * g.bodyWidth * 0.27,
                                        g.bodyCY + g.bodyHeight * 0.05)
              controlPoint2:NSMakePoint(g.cx + side * g.bodyWidth * 0.24,
                                        g.bodyCY - g.bodyHeight * 0.08)];
        ChickenDrawStroke(crease, 1.2, ToyColor(0xC28D0A, 0.34));
        [NSGraphicsContext restoreGraphicsState];

        wing.lineWidth = 1.1;
        [ToyColor(0xC28D0A, 0.35) setStroke];
        [wing stroke];
    }
}

- (void)drawBowTieWithGeometry:(ChickenGeometry)g
{
    CGFloat centerY = g.bodyTop - 2.0;
    CGFloat centerX = g.cx;
    NSRect tieRect = NSMakeRect(centerX - 38.0, centerY - 17.0, 76.0, 34.0);

    NSBezierPath *left = [NSBezierPath bezierPath];
    [left moveToPoint:NSMakePoint(centerX - 4.0, centerY)];
    [left curveToPoint:NSMakePoint(centerX - 37.0, centerY + 14.0)
         controlPoint1:NSMakePoint(centerX - 15.0, centerY + 4.0)
         controlPoint2:NSMakePoint(centerX - 28.0, centerY + 15.0)];
    [left curveToPoint:NSMakePoint(centerX - 35.0, centerY - 14.0)
         controlPoint1:NSMakePoint(centerX - 48.0, centerY + 6.0)
         controlPoint2:NSMakePoint(centerX - 48.0, centerY - 8.0)];
    [left curveToPoint:NSMakePoint(centerX - 4.0, centerY)
         controlPoint1:NSMakePoint(centerX - 24.0, centerY - 10.0)
         controlPoint2:NSMakePoint(centerX - 15.0, centerY - 2.0)];
    [left closePath];

    NSBezierPath *right = [NSBezierPath bezierPath];
    [right moveToPoint:NSMakePoint(centerX + 4.0, centerY)];
    [right curveToPoint:NSMakePoint(centerX + 37.0, centerY + 14.0)
          controlPoint1:NSMakePoint(centerX + 15.0, centerY + 4.0)
          controlPoint2:NSMakePoint(centerX + 28.0, centerY + 15.0)];
    [right curveToPoint:NSMakePoint(centerX + 35.0, centerY - 14.0)
          controlPoint1:NSMakePoint(centerX + 48.0, centerY + 6.0)
          controlPoint2:NSMakePoint(centerX + 48.0, centerY - 8.0)];
    [right curveToPoint:NSMakePoint(centerX + 4.0, centerY)
          controlPoint1:NSMakePoint(centerX + 24.0, centerY - 10.0)
          controlPoint2:NSMakePoint(centerX + 15.0, centerY - 2.0)];
    [right closePath];

    for (NSBezierPath *loop in @[left, right]) {
        ToyFillVertical(loop, ChickenRedBottom(), ChickenRedTop(), tieRect);
        loop.lineWidth = 1.1;
        [ToyColor(0x82121A, 0.45) setStroke];
        [loop stroke];
        NSBezierPath *shine = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(NSMinX(loop.bounds) + 7.0,
                                                                                centerY + 2.0,
                                                                                NSWidth(loop.bounds) * 0.35,
                                                                                4.0)];
        [ToyColor(0xFFA79A, 0.35) setFill];
        [shine fill];
    }

    NSRect knotRect = NSMakeRect(centerX - 9.0, centerY - 11.0, 18.0, 22.0);
    NSBezierPath *knot = [NSBezierPath bezierPathWithRoundedRect:knotRect xRadius:7.0 yRadius:7.0];
    ToyFillVertical(knot, ToyColor(0x9E121B, 1.0), ToyColor(0xE03435, 1.0),
                    NSMakeRect(knotRect.origin.x, knotRect.origin.y - 4.0,
                               knotRect.size.width, knotRect.size.height + 8.0));
    knot.lineWidth = 1.0;
    [ToyColor(0x7D0F16, 0.50) setStroke];
    [knot stroke];
}

- (void)drawCombWithGeometry:(ChickenGeometry)g
{
    NSBezierPath *comb = ChickenCombPath(g);
    NSRect combRect = NSInsetRect(comb.bounds, -8.0, -8.0);
    ToyFillVertical(comb, ChickenRedBottom(), ChickenRedTop(), combRect);

    [NSGraphicsContext saveGraphicsState];
    [comb addClip];
    NSBezierPath *shine = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(g.headCX - 25.0,
                                                                            g.headCY + g.headRY + 5.0,
                                                                            26.0, 8.0)];
    ToyFillRadial(shine, ToyColor(0xFFB09E, 0.42), ToyColor(0xFFB09E, 0.0),
                  NSMakePoint(g.headCX - 13.0, g.headCY + g.headRY + 9.0), 1.0, 18.0);
    [NSGraphicsContext restoreGraphicsState];

    comb.lineWidth = 1.1;
    [ToyColor(0x8B1119, 0.55) setStroke];
    [comb stroke];
}

- (void)drawHeadWithGeometry:(ChickenGeometry)g
{
    NSRect headRect = NSMakeRect(g.headCX - g.headRX, g.headCY - g.headRY,
                                 g.headRX * 2.0, g.headRY * 2.0);
    NSBezierPath *head = [NSBezierPath bezierPathWithOvalInRect:headRect];
    ToyFillVertical(head, ChickenYellowBottom(), ChickenYellowTop(),
                    NSMakeRect(0.0, 0.0, kChickenDesignWidth, kChickenDesignHeight));

    ToyFillRadial(head, ToyColor(0xFFFFFF, 0.25), ToyColor(0xFFFFFF, 0.0),
                  NSMakePoint(g.headCX - 16.0, g.headCY + 16.0), 2.0, 48.0);

    [NSGraphicsContext saveGraphicsState];
    [head addClip];
    NSGradient *chinShade = [[NSGradient alloc] initWithStartingColor:ToyColor(0xC7910A, 0.20)
                                                         endingColor:ToyColor(0xC7910A, 0.0)];
    [chinShade drawInRect:NSMakeRect(headRect.origin.x, headRect.origin.y,
                                     headRect.size.width, headRect.size.height * 0.45)
                    angle:90.0];
    [NSGraphicsContext restoreGraphicsState];

    head.lineWidth = 1.2;
    [ToyColor(0xC5910C, 0.38) setStroke];
    [head stroke];

    // Wattle hangs behind the beak.
    for (NSInteger sideIndex = 0; sideIndex <= 1; sideIndex++) {
        NSBezierPath *wattle = ChickenWattlePath(g, sideIndex == 0);
        ToyFillVertical(wattle, ToyColor(0xA9151D, 1.0), ToyColor(0xE43A35, 1.0),
                        NSInsetRect([wattle bounds], -4.0, -4.0));
        wattle.lineWidth = 0.9;
        [ToyColor(0x8C1017, 0.50) setStroke];
        [wattle stroke];
    }

    [self drawBeakWithGeometry:g];
}

- (void)drawBeakWithGeometry:(ChickenGeometry)g
{
    CGFloat centerX = g.headCX;
    CGFloat centerY = g.headCY;
    CGFloat open = g.beakOpen;
    CGFloat lowerTop = centerY - 12.0 - open;

    // The dark mouth appears only while the lower beak is swinging down.
    if (open > 8.0) {
        NSRect cavityRect = NSMakeRect(centerX - 13.0, lowerTop - 5.0,
                                       26.0, open + 15.0);
        NSBezierPath *cavity = [NSBezierPath bezierPathWithRoundedRect:cavityRect
                                                              xRadius:10.0
                                                              yRadius:10.0];
        ToyFillVertical(cavity, ToyColor(0x3B1014, 1.0), ToyColor(0x7C201D, 1.0),
                        NSInsetRect(cavityRect, -4.0, -4.0));

        if (open > 10.0) {
            [NSGraphicsContext saveGraphicsState];
            [cavity addClip];
            NSRect tongueRect = NSMakeRect(centerX - 9.0, lowerTop + 1.0, 18.0, 9.0);
            NSBezierPath *tongue = [NSBezierPath bezierPathWithOvalInRect:tongueRect];
            ToyFillVertical(tongue, ToyColor(0x8F2931, 1.0), ToyColor(0xD45A57, 1.0),
                            NSInsetRect(tongueRect, -2.0, -2.0));
            [NSGraphicsContext restoreGraphicsState];
        }
    }

    // Lower beak, hinged so it drops away from the upper beak.
    NSBezierPath *lower = [NSBezierPath bezierPath];
    [lower moveToPoint:NSMakePoint(centerX - 13.0, lowerTop)];
    [lower curveToPoint:NSMakePoint(centerX + 13.0, lowerTop)
          controlPoint1:NSMakePoint(centerX - 7.0, lowerTop + 1.0)
          controlPoint2:NSMakePoint(centerX + 7.0, lowerTop + 1.0)];
    [lower curveToPoint:NSMakePoint(centerX, lowerTop - 11.0)
          controlPoint1:NSMakePoint(centerX + 9.0, lowerTop - 2.0)
          controlPoint2:NSMakePoint(centerX + 4.0, lowerTop - 10.0)];
    [lower curveToPoint:NSMakePoint(centerX - 13.0, lowerTop)
          controlPoint1:NSMakePoint(centerX - 4.0, lowerTop - 10.0)
          controlPoint2:NSMakePoint(centerX - 9.0, lowerTop - 2.0)];
    [lower closePath];
    ToyFillVertical(lower, ToyColor(0xE99A17, 1.0), ToyColor(0xFFE07A, 1.0),
                    NSInsetRect([lower bounds], -3.0, -3.0));
    lower.lineWidth = 0.9;
    [ToyColor(0x9E580B, 0.55) setStroke];
    [lower stroke];

    // Upper beak, a rounded wedge pointing down.
    NSBezierPath *upper = [NSBezierPath bezierPath];
    [upper moveToPoint:NSMakePoint(centerX - 20.0, centerY - 2.0)];
    [upper curveToPoint:NSMakePoint(centerX + 20.0, centerY - 2.0)
         controlPoint1:NSMakePoint(centerX - 11.0, centerY + 8.0)
         controlPoint2:NSMakePoint(centerX + 11.0, centerY + 8.0)];
    [upper curveToPoint:NSMakePoint(centerX, centerY - 20.0)
         controlPoint1:NSMakePoint(centerX + 17.0, centerY - 6.0)
         controlPoint2:NSMakePoint(centerX + 10.0, centerY - 17.0)];
    [upper curveToPoint:NSMakePoint(centerX - 20.0, centerY - 2.0)
         controlPoint1:NSMakePoint(centerX - 10.0, centerY - 17.0)
         controlPoint2:NSMakePoint(centerX - 17.0, centerY - 6.0)];
    [upper closePath];
    ToyFillVertical(upper, ToyColor(0xF2A71A, 1.0), ToyColor(0xFFE076, 1.0),
                    NSInsetRect([upper bounds], -3.0, -3.0));
    upper.lineWidth = 1.0;
    [ToyColor(0xB86A0D, 0.55) setStroke];
    [upper stroke];

    NSBezierPath *ridge = [NSBezierPath bezierPath];
    [ridge moveToPoint:NSMakePoint(centerX, centerY - 3.0)];
    [ridge lineToPoint:NSMakePoint(centerX, centerY - 17.0)];
    ChickenDrawStroke(ridge, 1.0, ToyColor(0xCE7C12, 0.38));

    NSBezierPath *beakShine = [NSBezierPath bezierPathWithOvalInRect:
        NSMakeRect(centerX - 11.0, centerY + 1.0, 9.0, 2.5)];
    [ToyColor(0xFFF5C6, 0.60) setFill];
    [beakShine fill];
}

- (void)drawFaceWithGeometry:(ChickenGeometry)g
{
    CGFloat eyeShift = g.squeeze * 1.7;
    [self drawEyeAtCenter:NSMakePoint(g.headCX - 21.0 - eyeShift, g.headCY + 21.0)
                    bulge:g.eyeBulge
                  squeezed:g.squeeze];
    [self drawEyeAtCenter:NSMakePoint(g.headCX + 21.0 + eyeShift, g.headCY + 21.0)
                    bulge:g.eyeBulge
                  squeezed:g.squeeze];

    // Tiny nostril dots on the beak base.
    for (NSInteger side = -1; side <= 1; side += 2) {
        NSRect dotRect = NSMakeRect(g.headCX + side * 7.0 - 1.2, g.headCY + 3.0, 2.4, 2.0);
        NSBezierPath *dot = [NSBezierPath bezierPathWithOvalInRect:dotRect];
        [ToyColor(0xB87012, 0.55) setFill];
        [dot fill];
    }
}

- (void)drawEyeAtCenter:(NSPoint)center bulge:(CGFloat)bulge squeezed:(CGFloat)squeezed
{
    CGFloat width = 25.0 * bulge;
    CGFloat height = 29.0 * bulge;
    NSRect eyeRect = NSMakeRect(center.x - width * 0.5, center.y - height * 0.5, width, height);
    NSBezierPath *eye = [NSBezierPath bezierPathWithOvalInRect:eyeRect];
    NSGradient *whiteGradient = [[NSGradient alloc] initWithStartingColor:ToyColor(0xEDE9C9, 1.0)
                                                             endingColor:ToyColor(0xFFFEF1, 1.0)];
    [whiteGradient drawInBezierPath:eye angle:90.0];
    eye.lineWidth = 1.2;
    [ToyColor(0xC7A64B, 0.60) setStroke];
    [eye stroke];

    CGFloat pupilRadius = 6.4 - squeezed * 0.4;
    NSRect pupilRect = NSMakeRect(center.x - pupilRadius, center.y - pupilRadius - 1.0,
                                  pupilRadius * 2.0, pupilRadius * 2.0);
    NSBezierPath *pupil = [NSBezierPath bezierPathWithOvalInRect:pupilRect];
    [[NSColor colorWithSRGBRed:0.08 green:0.09 blue:0.09 alpha:1.0] setFill];
    [pupil fill];

    NSBezierPath *highlight = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(center.x - 4.2,
                                                                                center.y + 1.4,
                                                                                3.2, 4.0)];
    [ToyColor(0xFFFFFF, 0.85) setFill];
    [highlight fill];

    NSBezierPath *small = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(center.x + 1.5,
                                                                           center.y - 5.0,
                                                                           1.5, 1.8)];
    [ToyColor(0xFFFFFF, 0.35) setFill];
    [small fill];
}

- (void)drawSquawkScaleWithGeometry:(ChickenGeometry)g
{
    static const double frequencies[] = {
        880.000, 1046.502, 1174.659, 1318.510, 1567.982
    };
    static const NSInteger noteCount = 5;
    const CGFloat left = 96.0;
    const CGFloat right = 364.0;
    const CGFloat railY = 31.0;
    const CGFloat spacing = (right - left) / (CGFloat)(noteCount - 1);

    ToyDrawText(@"SQUAWK SCALE", NSMakePoint(left, 41.0),
                ToyMonoFont(7.4, NSFontWeightSemibold), ToyColor(0xF2C34E, 0.48), 1.25);

    NSBezierPath *rail = [NSBezierPath bezierPath];
    [rail moveToPoint:NSMakePoint(left, railY)];
    [rail lineToPoint:NSMakePoint(right, railY)];
    rail.lineWidth = 1.0;
    [ToyColor(0xF2C34E, 0.19) setStroke];
    [rail stroke];

    BOOL showNote = (_pressing || _squeezeValue > 0.04) && _squawkFrequency > 0.0;
    NSInteger activeIndex = -1;
    if (showNote) {
        double bestDistance = 1.0;
        for (NSInteger index = 0; index < noteCount; index++) {
            double distance = fabs(log2(_squawkFrequency / frequencies[index]) * 12.0);
            if (distance < bestDistance) {
                bestDistance = distance;
                activeIndex = index;
            }
        }
    }

    for (NSInteger index = 0; index < noteCount; index++) {
        BOOL active = index == activeIndex;
        CGFloat x = left + spacing * (CGFloat)index;
        NSColor *tickColor = active ? ToyColor(0xFFDE8A, 0.98) : ToyColor(0xF2C34E, 0.32);
        NSBezierPath *tick = [NSBezierPath bezierPath];
        [tick moveToPoint:NSMakePoint(x, railY - (active ? 7.0 : 4.0))];
        [tick lineToPoint:NSMakePoint(x, railY + (active ? 6.0 : 4.0))];
        tick.lineWidth = active ? 1.7 : 1.1;
        [tickColor setStroke];
        [tick stroke];

        if (active) {
            NSBezierPath *dot = [NSBezierPath bezierPathWithOvalInRect:
                NSMakeRect(x - 2.6, railY - 2.6, 5.2, 5.2)];
            NSShadow *glow = [[NSShadow alloc] init];
            glow.shadowBlurRadius = 9.0;
            glow.shadowColor = ToyColor(0xF2C34E, 0.95);
            glow.shadowOffset = NSMakeSize(0.0, 0.0);
            [NSGraphicsContext saveGraphicsState];
            [glow set];
            [ToyColor(0xFFF3C0, 1.0) setFill];
            [dot fill];
            [NSGraphicsContext restoreGraphicsState];
        }

        NSString *name = ToyNoteNameForFrequency(frequencies[index]);
        NSFont *font = ToyMonoFont(active ? 10.4 : 9.2,
                                   active ? NSFontWeightSemibold : NSFontWeightMedium);
        NSSize nameSize = ToyTextSize(name, font, 0.3);
        ToyDrawText(name, NSMakePoint(x - nameSize.width * 0.5, 8.0),
                    font, active ? ToyColor(0xFFE69B, 1.0) : ToyColor(0xF2C34E, 0.42), 0.3);
    }

    (void)g;
}

- (void)drawNoteTagWithGeometry:(ChickenGeometry)g
{
    if (!(_pressing || _squeezeValue > 0.04) || _squawkFrequency <= 0.0) {
        return;
    }

    NSString *name = ToyNoteNameForFrequency(_squawkFrequency);
    NSFont *noteFont = ToyMonoFont(9.4, NSFontWeightSemibold);
    NSSize noteSize = ToyTextSize(name, noteFont, 0.3);
    CGFloat tagWidth = noteSize.width + 34.0;
    CGFloat tagHeight = 22.0;
    CGFloat tagX = g.headCX + 64.0;
    CGFloat tagY = g.headCY + 16.0;
    if (tagX + tagWidth > 444.0) {
        tagX = 444.0 - tagWidth;
    }
    NSRect tagRect = NSMakeRect(tagX, tagY, tagWidth, tagHeight);
    NSBezierPath *tag = [NSBezierPath bezierPathWithRoundedRect:tagRect xRadius:11.0 yRadius:11.0];

    NSBezierPath *leader = [NSBezierPath bezierPath];
    [leader moveToPoint:NSMakePoint(g.headCX + g.headRX - 2.0, tagY + tagHeight * 0.5)];
    [leader lineToPoint:NSMakePoint(tagX, tagY + tagHeight * 0.5)];
    leader.lineWidth = 1.0;
    [ToyColor(0xF2C34E, 0.30) setStroke];
    [leader stroke];

    [ToyColor(0x101216, 0.86) setFill];
    [tag fill];
    tag.lineWidth = 1.0;
    [ToyColor(0xF2C34E, 0.42) setStroke];
    [tag stroke];

    NSFont *symbolFont = [NSFont systemFontOfSize:11.5 weight:NSFontWeightMedium];
    ToyDrawText(@"♪", NSMakePoint(tagX + 9.0, tagY + 4.4),
                symbolFont, ToyColor(0xFFD873, 0.95), 0.0);
    ToyDrawText(name, NSMakePoint(tagX + 22.0, tagY + (tagHeight - noteSize.height) * 0.5),
                noteFont, ToyColor(0xFFF1C7, 0.96), 0.3);
}

@end
