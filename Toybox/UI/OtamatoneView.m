#import "OtamatoneView.h"

#import "ToyAudioEngine.h"
#import "ToyMusic.h"
#import "ToyTheme.h"
#import <QuartzCore/QuartzCore.h>

static const CGFloat kOtoDesignWidth = 420.0;
static const CGFloat kOtoDesignHeight = 640.0;
static const double kOtoMinimumFrequency = 220.0;
static const double kOtoMaximumFrequency = 880.0;
static const CGFloat kOtoPitchLowY = 266.0;
static const CGFloat kOtoPitchHighY = 500.0;
static const CGFloat kOtoSlotTop = 500.0;
static const CGFloat kOtoSlotBottom = 266.0;

static NSColor *OtoMintTop(void)
{
    return ToyColor(0xA8F2E0, 1.0);
}

static NSColor *OtoMintBottom(void)
{
    return ToyColor(0x55C8B3, 1.0);
}

static NSColor *OtoDeepSlate(void)
{
    return ToyColor(0x35434B, 1.0);
}

static NSBezierPath *OtoHeadPath(void)
{
    return [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(98.0, 44.0, 220.0, 200.0)];
}

static NSBezierPath *OtoNeckPath(void)
{
    NSBezierPath *path = [NSBezierPath bezierPath];
    [path moveToPoint:NSMakePoint(172.0, 210.0)];
    [path curveToPoint:NSMakePoint(182.0, 506.0)
          controlPoint1:NSMakePoint(174.0, 318.0)
          controlPoint2:NSMakePoint(178.0, 422.0)];
    [path curveToPoint:NSMakePoint(234.0, 506.0)
          controlPoint1:NSMakePoint(188.0, 516.0)
          controlPoint2:NSMakePoint(228.0, 516.0)];
    [path curveToPoint:NSMakePoint(244.0, 210.0)
          controlPoint1:NSMakePoint(238.0, 422.0)
          controlPoint2:NSMakePoint(242.0, 318.0)];
    [path closePath];
    return path;
}

static NSBezierPath *OtoHookCenterline(void)
{
    NSBezierPath *path = [NSBezierPath bezierPath];
    [path moveToPoint:NSMakePoint(207.0, 478.0)];
    [path curveToPoint:NSMakePoint(212.0, 570.0)
          controlPoint1:NSMakePoint(204.0, 516.0)
          controlPoint2:NSMakePoint(206.0, 550.0)];
    [path curveToPoint:NSMakePoint(280.0, 587.0)
          controlPoint1:NSMakePoint(219.0, 601.0)
          controlPoint2:NSMakePoint(261.0, 604.0)];
    [path curveToPoint:NSMakePoint(296.0, 548.0)
          controlPoint1:NSMakePoint(303.0, 572.0)
          controlPoint2:NSMakePoint(305.0, 552.0)];
    [path curveToPoint:NSMakePoint(272.0, 534.0)
          controlPoint1:NSMakePoint(290.0, 543.0)
          controlPoint2:NSMakePoint(281.0, 535.0)];
    return path;
}

static NSBezierPath *OtoMouthPath(CGFloat open)
{
    CGFloat height = 5.0 + 46.0 * open;
    CGFloat top = 116.0 + 2.0 * open;
    NSBezierPath *path = [NSBezierPath bezierPath];
    [path moveToPoint:NSMakePoint(149.0, top)];
    [path curveToPoint:NSMakePoint(267.0, top)
          controlPoint1:NSMakePoint(183.0, top + 5.0 + 2.0 * open)
          controlPoint2:NSMakePoint(233.0, top + 5.0 + 2.0 * open)];
    [path curveToPoint:NSMakePoint(149.0, top)
          controlPoint1:NSMakePoint(240.0, top - height)
          controlPoint2:NSMakePoint(176.0, top - height)];
    [path closePath];
    return path;
}

static void OtoDrawGradientInCGPath(CGContextRef context, CGPathRef path, NSGradient *gradient, NSRect rect)
{
    CGContextSaveGState(context);
    CGContextAddPath(context, path);
    CGContextClip(context);
    [gradient drawInRect:rect angle:90.0];
    CGContextRestoreGState(context);
}

static void OtoSpringStep(CGFloat *value, CGFloat *velocity, CGFloat target,
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

@interface OtamatoneView ()
@property (nonatomic, strong) ToyAudioEngine *audioEngine;
@end

@implementation OtamatoneView {
    NSTimer *_animationTimer;
    NSTrackingArea *_trackingArea;
    NSTimeInterval _lastTickTime;
    NSTimeInterval _singStartTime;
    NSTimeInterval _nextBlinkTime;
    NSTimeInterval _blinkStartTime;
    BOOL _blinking;
    BOOL _singing;
    BOOL _hovering;
    CGFloat _mouthValue;
    CGFloat _mouthVelocity;
    CGFloat _mouthOpen;
    CGFloat _blinkAmount;
    double _pitchFrequency;
}

- (instancetype)initWithAudioEngine:(ToyAudioEngine *)audioEngine
{
    self = [super initWithFrame:NSZeroRect];
    if (self) {
        _audioEngine = audioEngine;
        _pitchFrequency = kOtoMinimumFrequency;
        _nextBlinkTime = CACurrentMediaTime() + 4.0 + arc4random_uniform(4000) / 1000.0;
        self.wantsLayer = NO;
        [self setAccessibilityElement:YES];
        [self setAccessibilityRole:NSAccessibilityGroupRole];
        [self setAccessibilityLabel:@"Otamatone"];
        [self setAccessibilityHelp:@"Press and hold to sing. Drag vertically to play notes from A3 to A5 on the A minor scale."];
        [audioEngine setOtamatoneFrequency:_pitchFrequency];
        [audioEngine setOtamatoneMouth:0.0];
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
    [_audioEngine setOtamatoneGate:0.0];
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

- (void)updateTrackingAreas
{
    [super updateTrackingAreas];
    if (_trackingArea) {
        [self removeTrackingArea:_trackingArea];
    }
    _trackingArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect
                                                options:NSTrackingMouseEnteredAndExited |
                                                        NSTrackingActiveInKeyWindow |
                                                        NSTrackingInVisibleRect
                                                  owner:self
                                               userInfo:nil];
    [self addTrackingArea:_trackingArea];
}

- (void)resetCursorRects
{
    [super resetCursorRects];
    ToyFit fit = ToyFitMake(self.bounds, kOtoDesignWidth, kOtoDesignHeight);
    NSRect toyRect = NSMakeRect(90.0, 36.0, 250.0, 588.0);
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
    return ToyFitMake(self.bounds, kOtoDesignWidth, kOtoDesignHeight);
}

- (NSPoint)designPointForEvent:(NSEvent *)event
{
    NSPoint viewPoint = [self convertPoint:event.locationInWindow fromView:nil];
    return ToyFitPoint([self currentFit], viewPoint);
}

- (BOOL)toyContainsDesignPoint:(NSPoint)point
{
    if ([OtoHeadPath() containsPoint:point] || [OtoNeckPath() containsPoint:point]) {
        return YES;
    }
    if (NSMouseInRect(point, NSMakeRect(180.0, 486.0, 140.0, 126.0), NO)) {
        return YES;
    }
    return NO;
}

- (double)frequencyForDesignY:(CGFloat)y
{
    double t = ToyClampDouble((y - kOtoPitchLowY) / (kOtoPitchHighY - kOtoPitchLowY), 0.0, 1.0);
    return kOtoMinimumFrequency * pow(kOtoMaximumFrequency / kOtoMinimumFrequency, t);
}

- (void)beginSingingAtDesignPoint:(NSPoint)point
{
    _singing = YES;
    _hovering = YES;
    _blinking = NO;
    _blinkAmount = 0.0;
    if (point.y >= 205.0) {
        _pitchFrequency = [self frequencyForDesignY:point.y];
    }
    _singStartTime = CACurrentMediaTime();
    _mouthValue = MAX(_mouthValue, 0.12);
    _mouthVelocity += 4.2;
    [_audioEngine setOtamatoneFrequency:_pitchFrequency];
    [_audioEngine setOtamatoneGate:1.0];
    [self setNeedsDisplay:YES];
}

- (void)endSinging
{
    if (!_singing) {
        return;
    }
    _singing = NO;
    [_audioEngine setOtamatoneGate:0.0];
    [self setNeedsDisplay:YES];
}

- (void)cancelInteraction
{
    [self endSinging];
}

- (void)mouseDown:(NSEvent *)event
{
    NSPoint point = [self designPointForEvent:event];
    if (![self toyContainsDesignPoint:point]) {
        [super mouseDown:event];
        return;
    }
    [self beginSingingAtDesignPoint:point];
}

- (void)mouseDragged:(NSEvent *)event
{
    if (!_singing) {
        [super mouseDragged:event];
        return;
    }
    NSPoint point = [self designPointForEvent:event];
    _pitchFrequency = [self frequencyForDesignY:point.y];
    [_audioEngine setOtamatoneFrequency:_pitchFrequency];
    [self setNeedsDisplay:YES];
}

- (void)mouseUp:(NSEvent *)event
{
    [self endSinging];
    [super mouseUp:event];
}

- (void)mouseEntered:(NSEvent *)event
{
    (void)event;
    _hovering = YES;
    [self setNeedsDisplay:YES];
}

- (void)mouseExited:(NSEvent *)event
{
    (void)event;
    if (!_singing) {
        _hovering = NO;
        [self setNeedsDisplay:YES];
    }
}

- (void)animationTick
{
    NSTimeInterval now = CACurrentMediaTime();
    CGFloat dt = (CGFloat)(now - _lastTickTime);
    _lastTickTime = now;
    if (dt <= 0.0 || dt > 0.05) {
        dt = 1.0 / 60.0;
    }

    CGFloat target = _singing ? 1.0 : 0.0;
    CGFloat previousMouth = _mouthValue;
    OtoSpringStep(&_mouthValue, &_mouthVelocity, target, 360.0, 25.0, dt);

    CGFloat jawWobble = _singing ? 0.035 * sin(now * M_PI * 2.0 * 5.3) * _mouthValue : 0.0;
    _mouthOpen = ToyClamp(_mouthValue + jawWobble, 0.0, 1.0);
    [_audioEngine setOtamatoneMouth:_mouthOpen];

    BOOL blinkChanged = NO;
    if (!_singing && !_blinking && now >= _nextBlinkTime) {
        _blinking = YES;
        _blinkStartTime = now;
        blinkChanged = YES;
    }
    if (_blinking) {
        CGFloat progress = (CGFloat)((now - _blinkStartTime) / 0.17);
        if (progress >= 1.0) {
            _blinking = NO;
            _blinkAmount = 0.0;
            _nextBlinkTime = now + 3.4 + arc4random_uniform(5000) / 1000.0;
        } else {
            _blinkAmount = sin(progress * M_PI);
        }
        blinkChanged = YES;
    }

    BOOL mouthAnimating = fabs(_mouthValue - previousMouth) > 0.0001 || fabs(_mouthVelocity) > 0.001;
    if (_singing || mouthAnimating || blinkChanged) {
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

    CGContextSaveGState(context);
    CGContextTranslateCTM(context, fit.offsetX, fit.offsetY);
    CGContextScaleCTM(context, fit.scale, fit.scale);

    [self drawHaloInContext:context atTime:now];
    ToyDrawContactShadow(NSMakePoint(208.0, 51.0), 248.0, 38.0, 1.0);
    [self drawBodyInContext:context];
    [self drawNeckSlotInContext:context];
    [self drawScaleRailInContext:context];
    [self drawFaceInContext:context];

    CGContextRestoreGState(context);
}

- (void)drawHaloInContext:(CGContextRef)context atTime:(NSTimeInterval)now
{
    CGFloat presence = MAX(_singing ? 1.0 : 0.0, _mouthOpen * 0.8);
    if (presence < 0.02) {
        return;
    }
    CGFloat pulse = 0.92 + 0.08 * sin(now * 2.1);
    NSColor *inner = ToyColor(0x7DEBD5, 0.11 * presence * pulse);
    NSColor *outer = ToyColor(0x7DEBD5, 0.0);
    [NSGraphicsContext saveGraphicsState];
    NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:inner endingColor:outer];
    [gradient drawFromCenter:NSMakePoint(208.0, 150.0) radius:8.0
                    toCenter:NSMakePoint(208.0, 150.0) radius:300.0
                     options:NSGradientDrawsAfterEndingLocation];
    [NSGraphicsContext restoreGraphicsState];
    (void)context;
}

- (void)drawBodyInContext:(CGContextRef)context
{
    NSGradient *bodyGradient = [[NSGradient alloc] initWithStartingColor:OtoMintBottom()
                                                           endingColor:OtoMintTop()];
    NSBezierPath *head = OtoHeadPath();
    NSBezierPath *neck = OtoNeckPath();

    // Neck first, then hook, then head; the head hides the neck joint.
    ToyFillVertical(neck, OtoMintBottom(), OtoMintTop(), NSMakeRect(0.0, 0.0, 420.0, 640.0));

    NSBezierPath *hookCenter = OtoHookCenterline();
    CGPathRef hookOutline = CGPathCreateCopyByStrokingPath(hookCenter.CGPath, NULL, 39.0,
                                                           kCGLineCapRound, kCGLineJoinRound,
                                                           20.0);
    if (hookOutline) {
        OtoDrawGradientInCGPath(context, hookOutline, bodyGradient, NSMakeRect(0.0, 0.0, 420.0, 640.0));
        NSBezierPath *outlinePath = [NSBezierPath bezierPathWithCGPath:hookOutline];
        [outlinePath setLineWidth:1.3];
        [ToyColor(0x309B87, 0.28) setStroke];
        [outlinePath stroke];
        CGPathRelease(hookOutline);
    }

    ToyFillVertical(head, OtoMintBottom(), OtoMintTop(), NSMakeRect(0.0, 0.0, 420.0, 640.0));

    // Head form shading: warm top-left light, cool lower edge.
    ToyFillRadial(head, ToyColor(0xFFFFFF, 0.26), ToyColor(0xFFFFFF, 0.0),
                  NSMakePoint(151.0, 203.0), 8.0, 118.0);

    [NSGraphicsContext saveGraphicsState];
    [head addClip];
    NSGradient *lowerShade = [[NSGradient alloc] initWithStartingColor:ToyColor(0x228E7B, 0.16)
                                                         endingColor:ToyColor(0x228E7B, 0.0)];
    [lowerShade drawInRect:NSMakeRect(98.0, 44.0, 220.0, 150.0) angle:90.0];
    [NSGraphicsContext restoreGraphicsState];

    head.lineWidth = 1.2;
    [ToyColor(0xFFFFFF, 0.22) setStroke];
    [head stroke];

    // Soft specular reflection on the forehead.
    [NSGraphicsContext saveGraphicsState];
    [head addClip];
    NSGradient *specular = [[NSGradient alloc] initWithStartingColor:ToyColor(0xFFFFFF, 0.18)
                                                        endingColor:ToyColor(0xFFFFFF, 0.0)];
    [specular drawFromCenter:NSMakePoint(164.0, 199.0) radius:2.0
                    toCenter:NSMakePoint(164.0, 199.0) radius:76.0
                     options:0];
    [NSGraphicsContext restoreGraphicsState];

    // Neck edge light and ambient shadow.
    [NSGraphicsContext saveGraphicsState];
    [neck addClip];
    NSBezierPath *neckHighlight = [NSBezierPath bezierPath];
    [neckHighlight moveToPoint:NSMakePoint(185.0, 238.0)];
    [neckHighlight curveToPoint:NSMakePoint(191.0, 500.0)
                  controlPoint1:NSMakePoint(180.0, 320.0)
                  controlPoint2:NSMakePoint(184.0, 430.0)];
    [neckHighlight setLineWidth:4.0];
    neckHighlight.lineCapStyle = NSLineCapStyleRound;
    [ToyColor(0xFFFFFF, 0.16) setStroke];
    [neckHighlight stroke];

    NSGradient *neckShade = [[NSGradient alloc] initWithStartingColor:ToyColor(0x2A9C88, 0.0)
                                                         endingColor:ToyColor(0x2A9C88, 0.20)];
    [neckShade drawInRect:NSMakeRect(209.0, 220.0, 38.0, 290.0) angle:0.0];
    [NSGraphicsContext restoreGraphicsState];

    // Hook highlight follows the upper curve.
    NSBezierPath *hookHighlight = [OtoHookCenterline() copy];
    NSAffineTransform *shift = [NSAffineTransform transform];
    [shift translateXBy:-4.0 yBy:7.0];
    [hookHighlight transformUsingAffineTransform:shift];
    hookHighlight.lineWidth = 11.0;
    hookHighlight.lineCapStyle = NSLineCapStyleRound;
    CGPathRef hookForHighlight = CGPathCreateCopyByStrokingPath(hookCenter.CGPath, NULL, 39.0,
                                                                kCGLineCapRound, kCGLineJoinRound,
                                                                20.0);
    if (hookForHighlight) {
        CGContextSaveGState(context);
        CGContextAddPath(context, hookForHighlight);
        CGContextClip(context);
        [ToyColor(0xFFFFFF, 0.15) setStroke];
        [hookHighlight stroke];
        CGContextRestoreGState(context);
        CGPathRelease(hookForHighlight);
    }

    // Faint molded seam at the neck/head joint.
    NSBezierPath *seam = [NSBezierPath bezierPath];
    [seam moveToPoint:NSMakePoint(178.0, 219.0)];
    [seam curveToPoint:NSMakePoint(238.0, 219.0)
        controlPoint1:NSMakePoint(194.0, 227.0)
        controlPoint2:NSMakePoint(224.0, 227.0)];
    seam.lineWidth = 1.1;
    [ToyColor(0x3BAA96, 0.22) setStroke];
    [seam stroke];
}

- (void)drawNeckSlotInContext:(CGContextRef)context
{
    (void)context;
    NSRect outerRect = NSMakeRect(189.0, 250.0, 38.0, 266.0);
    NSRect innerRect = NSMakeRect(197.0, 258.0, 22.0, 250.0);

    NSBezierPath *outer = [NSBezierPath bezierPathWithRoundedRect:outerRect xRadius:17.0 yRadius:17.0];
    NSGradient *bevel = [[NSGradient alloc] initWithStartingColor:ToyColor(0x49B8A4, 1.0)
                                                       endingColor:ToyColor(0x8AE9D6, 1.0)];
    [bevel drawInBezierPath:outer angle:90.0];
    [outer setLineWidth:1.0];
    [ToyColor(0x2D9C89, 0.45) setStroke];
    [outer stroke];

    NSBezierPath *inner = [NSBezierPath bezierPathWithRoundedRect:innerRect xRadius:11.0 yRadius:11.0];
    NSGradient *cavity = [[NSGradient alloc] initWithStartingColor:ToyColor(0x14191E, 1.0)
                                                       endingColor:ToyColor(0x343D45, 1.0)];
    [cavity drawInBezierPath:inner angle:90.0];

    [NSGraphicsContext saveGraphicsState];
    [inner addClip];
    NSGradient *innerShadow = [[NSGradient alloc] initWithStartingColor:ToyColor(0x000000, 0.34)
                                                         endingColor:ToyColor(0x000000, 0.0)];
    [innerShadow drawInRect:NSMakeRect(innerRect.origin.x, NSMaxY(innerRect) - 34.0,
                                       innerRect.size.width, 34.0)
                      angle:90.0];
    NSBezierPath *gloss = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(199.0, 268.0, 3.0, 228.0)
                                                        xRadius:1.5
                                                        yRadius:1.5];
    [ToyColor(0xFFFFFF, 0.07) setFill];
    [gloss fill];
    [NSGraphicsContext restoreGraphicsState];

    inner.lineWidth = 1.0;
    [ToyColor(0x000000, 0.35) setStroke];
    [inner stroke];

    NSBezierPath *lowerRim = [NSBezierPath bezierPath];
    [lowerRim moveToPoint:NSMakePoint(198.0, 260.0)];
    [lowerRim curveToPoint:NSMakePoint(218.0, 258.5)
             controlPoint1:NSMakePoint(204.0, 263.0)
             controlPoint2:NSMakePoint(212.0, 263.0)];
    lowerRim.lineWidth = 1.0;
    [ToyColor(0xB6F6E7, 0.33) setStroke];
    [lowerRim stroke];

    // Pitch puck
    double normalized = log(_pitchFrequency / kOtoMinimumFrequency) /
                        log(kOtoMaximumFrequency / kOtoMinimumFrequency);
    CGFloat puckY = kOtoSlotBottom + (CGFloat)ToyClampDouble(normalized, 0.0, 1.0) *
                                      (kOtoSlotTop - kOtoSlotBottom);
    CGFloat visibility = (_singing || _hovering) ? 1.0 : 0.35;
    NSRect puckRect = NSMakeRect(199.5, puckY - 12.0, 17.0, 24.0);
    NSBezierPath *puck = [NSBezierPath bezierPathWithRoundedRect:puckRect xRadius:8.5 yRadius:8.5];

    NSShadow *puckGlow = [[NSShadow alloc] init];
    puckGlow.shadowBlurRadius = 9.0;
    puckGlow.shadowColor = ToyColor(0x8DF1DC, 0.75 * visibility);
    puckGlow.shadowOffset = NSMakeSize(0.0, 0.0);

    [NSGraphicsContext saveGraphicsState];
    [puckGlow set];
    NSGradient *puckGradient = [[NSGradient alloc] initWithStartingColor:ToyColor(0x66D2BE, visibility)
                                                           endingColor:ToyColor(0xDFFFF7, visibility)];
    [puckGradient drawInBezierPath:puck angle:90.0];
    [NSGraphicsContext restoreGraphicsState];

    NSBezierPath *puckLine = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(202.0, puckY - 7.0, 12.0, 2.0)
                                                            xRadius:1.0
                                                            yRadius:1.0];
    [ToyColor(0xFFFFFF, 0.65 * visibility) setFill];
    [puckLine fill];
}

- (CGFloat)scaleYForFrequency:(double)frequency
{
    double normalized = log(frequency / kOtoMinimumFrequency) /
                        log(kOtoMaximumFrequency / kOtoMinimumFrequency);
    return kOtoPitchLowY + (CGFloat)ToyClampDouble(normalized, 0.0, 1.0) *
                           (kOtoPitchHighY - kOtoPitchLowY);
}

- (void)drawScaleRailInContext:(CGContextRef)context
{
    (void)context;

    static const NSInteger scaleNotes[] = {
        57, 59, 60, 62, 64, 65, 67, 69, 71, 72, 74, 76, 77, 79, 81
    };
    static const NSInteger scaleCount = (NSInteger)(sizeof(scaleNotes) / sizeof(scaleNotes[0]));

    const CGFloat spineX = 322.0;
    const CGFloat labelX = 336.0;
    const CGFloat staggerX = 374.0;
    NSFont *captionFont = ToyMonoFont(10.6, NSFontWeightSemibold);
    NSColor *captionColor = ToyColor(0x9FF1E2, 0.58);
    NSString *captionText = @"A MINOR";
    CGFloat captionY = kOtoPitchHighY + 14.0;
    ToyDrawText(captionText, NSMakePoint(spineX - 8.0, captionY),
                captionFont, captionColor, 1.1);
    NSSize captionSize = ToyTextSize(captionText, captionFont, 1.1);
    ToyDrawText(@"A3–A5",
                NSMakePoint(spineX - 8.0 + captionSize.width + 9.0, captionY + 0.5),
                ToyMonoFont(8.8, NSFontWeightMedium), ToyColor(0x8FE6D7, 0.36), 0.6);

    NSBezierPath *spine = [NSBezierPath bezierPath];
    [spine moveToPoint:NSMakePoint(spineX, kOtoPitchLowY - 6.0)];
    [spine lineToPoint:NSMakePoint(spineX, kOtoPitchHighY + 6.0)];
    spine.lineWidth = 1.3;
    spine.lineCapStyle = NSLineCapStyleRound;
    [ToyColor(0x8FE6D7, 0.19) setStroke];
    [spine stroke];

    NSInteger activeIndex = -1;
    double activeDistance = 0.55;
    for (NSInteger index = 0; index < scaleCount; index++) {
        double noteFrequency = ToyFrequencyForMIDINote(scaleNotes[index]);
        double distance = fabs(log2(_pitchFrequency / noteFrequency) * 12.0);
        if (distance < activeDistance) {
            activeDistance = distance;
            activeIndex = index;
        }
    }

    CGFloat previousY = -1000.0;
    for (NSInteger index = 0; index < scaleCount; index++) {
        BOOL active = index == activeIndex;
        double noteFrequency = ToyFrequencyForMIDINote(scaleNotes[index]);
        CGFloat y = [self scaleYForFrequency:noteFrequency];
        BOOL staggered = index > 0 && (y - previousY) < 14.0;
        previousY = y;
        CGFloat labelPositionX = staggered ? staggerX : labelX;

        NSColor *tickColor = active ? ToyColor(0xD9FFF8, 0.95) : ToyColor(0x8FE6D7, 0.40);
        NSBezierPath *tick = [NSBezierPath bezierPath];
        [tick moveToPoint:NSMakePoint(spineX - (active ? 10.0 : 7.0), y)];
        [tick lineToPoint:NSMakePoint(spineX + (active ? 7.0 : 4.0), y)];
        tick.lineWidth = active ? 2.3 : 1.4;
        [tickColor setStroke];
        [tick stroke];

        if (staggered) {
            NSBezierPath *staggerLeader = [NSBezierPath bezierPath];
            [staggerLeader moveToPoint:NSMakePoint(spineX + 4.0, y)];
            [staggerLeader lineToPoint:NSMakePoint(staggerX - 5.0, y)];
            staggerLeader.lineWidth = 1.0;
            [ToyColor(0x8FE6D7, active ? 0.38 : 0.16) setStroke];
            [staggerLeader stroke];
        }

        if (active) {
            NSBezierPath *dot = [NSBezierPath bezierPathWithOvalInRect:
                NSMakeRect(spineX - 4.25, y - 4.25, 8.5, 8.5)];
            NSShadow *glow = [[NSShadow alloc] init];
            glow.shadowBlurRadius = 11.0;
            glow.shadowColor = ToyColor(0x8DF1DC, 0.92);
            glow.shadowOffset = NSMakeSize(0.0, 0.0);
            [NSGraphicsContext saveGraphicsState];
            [glow set];
            [ToyColor(0xE4FFF9, 1.0) setFill];
            [dot fill];
            [NSGraphicsContext restoreGraphicsState];
        }

        NSString *name = ToyNoteNameForMIDINote(scaleNotes[index]);
        NSFont *font = ToyMonoFont(active ? 17.8 : 16.5,
                                   active ? NSFontWeightSemibold : NSFontWeightMedium);
        NSSize nameSize = ToyTextSize(name, font, 0.25);

        if (active) {
            const CGFloat pillPadX = 7.0;
            NSRect pillRect = NSMakeRect(labelPositionX - pillPadX, y - 10.5,
                                         nameSize.width + pillPadX * 2.0, 21.0);
            NSBezierPath *pill = [NSBezierPath bezierPathWithRoundedRect:pillRect
                                                                xRadius:10.5
                                                                yRadius:10.5];
            [ToyColor(0x0A1014, 0.84) setFill];
            [pill fill];
            pill.lineWidth = 1.2;
            [ToyColor(0x8FE6D7, 0.38) setStroke];
            [pill stroke];
        }

        NSColor *nameColor = active ? ToyColor(0xE5FFF9, 0.98) : ToyColor(0x8FE6D7, 0.54);
        ToyDrawText(name, NSMakePoint(labelPositionX, y - nameSize.height * 0.5),
                    font, nameColor, 0.25);
    }

    double normalized = log(_pitchFrequency / kOtoMinimumFrequency) /
                        log(kOtoMaximumFrequency / kOtoMinimumFrequency);
    CGFloat puckY = kOtoSlotBottom + (CGFloat)ToyClampDouble(normalized, 0.0, 1.0) *
                                      (kOtoSlotTop - kOtoSlotBottom);
    CGFloat visibility = _singing ? 1.0 : (_hovering ? 0.78 : 0.42);

    NSBezierPath *leader = [NSBezierPath bezierPath];
    [leader moveToPoint:NSMakePoint(219.0, puckY)];
    [leader lineToPoint:NSMakePoint(246.0, puckY)];
    leader.lineWidth = 1.0;
    [ToyColor(0x8FE6D7, 0.30 * visibility) setStroke];
    [leader stroke];

    NSString *noteName = ToyNoteNameForFrequency(_pitchFrequency);
    NSFont *noteFont = ToyMonoFont(12.2, NSFontWeightSemibold);
    NSSize noteSize = ToyTextSize(noteName, noteFont, 0.35);
    CGFloat badgeWidth = MAX(44.0, noteSize.width + 16.0);
    NSRect badgeRect = NSMakeRect(247.0, puckY - 11.5, badgeWidth, 23.0);
    NSBezierPath *badge = [NSBezierPath bezierPathWithRoundedRect:badgeRect
                                                        xRadius:11.5
                                                        yRadius:11.5];
    [ToyColor(0x0A1014, 0.78 * visibility) setFill];
    [badge fill];
    badge.lineWidth = 1.0;
    [ToyColor(0x8FE6D7, 0.34 * visibility) setStroke];
    [badge stroke];
    ToyDrawText(noteName,
                NSMakePoint(NSMinX(badgeRect) + (badgeWidth - noteSize.width) * 0.5,
                            puckY - noteSize.height * 0.5),
                noteFont, ToyColor(0xDFFFF7, 0.92 * visibility), 0.35);
}

- (void)drawFaceInContext:(CGContextRef)context
{    // Eyes
    CGFloat blinkScale = 1.0 - 0.94 * _blinkAmount;
    [self drawEyeInContext:context center:NSMakePoint(166.0, 160.0) angle:-0.10
                   heightScale:blinkScale];
    [self drawEyeInContext:context center:NSMakePoint(250.0, 160.0) angle:0.10
                   heightScale:blinkScale];

    CGFloat open = _mouthOpen;
    NSBezierPath *mouth = OtoMouthPath(open);

    if (open > 0.025) {
        NSRect mouthRect = [mouth bounds];
        NSGradient *cavity = [[NSGradient alloc] initWithStartingColor:ToyColor(0x2B141B, 1.0)
                                                           endingColor:ToyColor(0x111419, 1.0)];
        [NSGraphicsContext saveGraphicsState];
        [mouth addClip];
        [cavity drawInRect:mouthRect angle:90.0];

        if (open > 0.14) {
            NSBezierPath *tongue = [NSBezierPath bezierPathWithOvalInRect:
                NSMakeRect(208.0 - 37.0 * (0.7 + 0.3 * open),
                           NSMinY(mouthRect) + 3.0,
                           74.0 * (0.7 + 0.3 * open),
                           15.0 + 20.0 * open)];
            ToyFillRadial(tongue, ToyColor(0xE88692, 0.95), ToyColor(0xB95264, 0.9),
                          NSMakePoint(208.0, NSMinY(mouthRect) + 10.0), 2.0, 44.0);
        }

        NSGradient *innerShadow = [[NSGradient alloc] initWithStartingColor:ToyColor(0x000000, 0.45)
                                                             endingColor:ToyColor(0x000000, 0.0)];
        [innerShadow drawInRect:NSMakeRect(NSMinX(mouthRect), NSMaxY(mouthRect) - 30.0,
                                           NSWidth(mouthRect), 30.0)
                          angle:90.0];
        [NSGraphicsContext restoreGraphicsState];

        [mouth setLineWidth:2.3];
        [ToyColor(0xBCF7E9, 0.44) setStroke];
        [mouth stroke];
    } else {
        NSBezierPath *smile = [NSBezierPath bezierPath];
        [smile moveToPoint:NSMakePoint(151.0, 120.0)];
        [smile curveToPoint:NSMakePoint(265.0, 120.0)
              controlPoint1:NSMakePoint(181.0, 106.0)
              controlPoint2:NSMakePoint(235.0, 106.0)];
        smile.lineWidth = 3.2;
        smile.lineCapStyle = NSLineCapStyleRound;
        [OtoDeepSlate() setStroke];
        [smile stroke];

        NSBezierPath *lipLight = [NSBezierPath bezierPath];
        [lipLight moveToPoint:NSMakePoint(155.0, 115.0)];
        [lipLight curveToPoint:NSMakePoint(261.0, 115.0)
                controlPoint1:NSMakePoint(183.0, 102.0)
                controlPoint2:NSMakePoint(233.0, 102.0)];
        lipLight.lineWidth = 1.0;
        [ToyColor(0xFFFFFF, 0.20) setStroke];
        [lipLight stroke];
    }
}

- (void)drawEyeInContext:(CGContextRef)context center:(NSPoint)center angle:(CGFloat)angle
             heightScale:(CGFloat)heightScale
{
    CGFloat width = 24.0;
    CGFloat height = 31.0 * MAX(heightScale, 0.045);

    CGContextSaveGState(context);
    CGContextTranslateCTM(context, center.x, center.y);
    CGContextRotateCTM(context, angle);

    NSBezierPath *eye = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(-width * 0.5,
                                                                          -height * 0.5,
                                                                          width, height)
                                                       xRadius:width * 0.5
                                                       yRadius:width * 0.5];
    [OtoDeepSlate() setFill];
    [eye fill];

    if (heightScale > 0.16) {
        NSBezierPath *highlight = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(-6.5, 3.5, 6.0, 8.5)];
        [ToyColor(0xFFFFFF, 0.68) setFill];
        [highlight fill];
        NSBezierPath *smallHighlight = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(3.0, -7.0, 2.6, 3.4)];
        [ToyColor(0xFFFFFF, 0.28) setFill];
        [smallHighlight fill];
    }

    CGContextRestoreGState(context);
}

@end
