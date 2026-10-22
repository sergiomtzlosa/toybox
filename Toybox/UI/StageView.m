#import "StageView.h"

#import "ToyPanelView.h"
#import "ToyRecordButton.h"
#import "ToyTheme.h"

static const CGFloat kStageSideMargin = 46.0;
static const CGFloat kStagePanelGap = 26.0;
static const CGFloat kStageBottomMargin = 40.0;
static const CGFloat kStageHeaderBottomInset = 142.0;

@interface StageView ()
@property (nonatomic, strong) NSArray<NSValue *> *currentPanelFrames;
@property (nonatomic, strong, readwrite) ToyRecordButton *recordButton;
@end

@implementation StageView

- (instancetype)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        _audioStatusText = @"AUDIO ENGINE LIVE";
        _audioOnline = YES;
        _currentPanelFrames = @[];
        _recordButton = [[ToyRecordButton alloc] initWithFrame:NSZeroRect];
        [self addSubview:_recordButton];
        self.autoresizesSubviews = NO;
    }
    return self;
}

- (BOOL)isOpaque
{
    return YES;
}

- (void)setPanels:(NSArray<ToyPanelView *> *)panels
{
    for (ToyPanelView *oldPanel in _panels) {
        [oldPanel removeFromSuperview];
    }
    _panels = [panels copy];
    for (ToyPanelView *panel in _panels) {
        [self addSubview:panel];
    }
    [self layoutPanels];
    [self setNeedsDisplay:YES];
}

- (void)setAudioStatusText:(NSString *)audioStatusText
{
    _audioStatusText = [audioStatusText copy];
    [self layoutRecordButton];
    [self setNeedsDisplay:YES];
}

- (void)setAudioOnline:(BOOL)audioOnline
{
    _audioOnline = audioOnline;
    [self setNeedsDisplay:YES];
}

- (void)setFrameSize:(NSSize)newSize
{
    [super setFrameSize:newSize];
    [self layoutPanels];
    [self layoutRecordButton];
    [self setNeedsDisplay:YES];
}

- (CGFloat)statusPillWidth
{
    NSString *text = self.audioStatusText ?: @"AUDIO";
    NSSize textSize = ToyTextSize(text, ToyMonoFont(9.2, NSFontWeightMedium), 1.15);
    return textSize.width + 33.0;
}

- (void)layoutRecordButton
{
    CGFloat width = NSWidth(self.bounds);
    CGFloat height = NSHeight(self.bounds);
    if (width <= 0.0 || height <= 0.0) {
        return;
    }
    CGFloat buttonWidth = 106.0;
    CGFloat x = width - kStageSideMargin - [self statusPillWidth] - 10.0 - buttonWidth;
    self.recordButton.frame = NSMakeRect(x, height - 70.0, buttonWidth, 25.0);
}

- (NSArray<NSValue *> *)panelFramesForBounds:(NSRect)bounds
{
    CGFloat width = NSWidth(bounds);
    CGFloat height = NSHeight(bounds);
    CGFloat panelWidth = (width - kStageSideMargin * 2.0 - kStagePanelGap) * 0.5;
    CGFloat top = height - kStageHeaderBottomInset;
    CGFloat panelHeight = MAX(220.0, top - kStageBottomMargin);
    NSRect left = NSMakeRect(kStageSideMargin, kStageBottomMargin, panelWidth, panelHeight);
    NSRect right = NSMakeRect(NSMaxX(left) + kStagePanelGap, kStageBottomMargin,
                              panelWidth, panelHeight);
    return @[ [NSValue valueWithRect:left], [NSValue valueWithRect:right] ];
}

- (void)layoutPanels
{
    if (self.panels.count < 2) {
        self.currentPanelFrames = @[];
        return;
    }
    NSArray<NSValue *> *frames = [self panelFramesForBounds:self.bounds];
    self.currentPanelFrames = frames;
    for (NSUInteger index = 0; index < 2; index++) {
        self.panels[index].frame = frames[index].rectValue;
    }
}

- (void)drawRect:(NSRect)dirtyRect
{
    (void)dirtyRect;
    NSRect bounds = self.bounds;
    CGFloat width = NSWidth(bounds);
    CGFloat height = NSHeight(bounds);

    NSGradient *background = [[NSGradient alloc] initWithStartingColor:ToyColor(0x080A0E, 1.0)
                                                         endingColor:ToyColor(0x171D26, 1.0)];
    [background drawInRect:bounds angle:90.0];

    // Colored stage lights behind each card.
    NSColor *mintGlow = ToyColor(0x67DCC6, 0.085);
    NSGradient *leftGlow = [[NSGradient alloc] initWithStartingColor:mintGlow
                                                         endingColor:ToyColor(0x67DCC6, 0.0)];
    NSPoint leftCenter = NSMakePoint(width * 0.27, height * 0.43);
    [leftGlow drawFromCenter:leftCenter radius:12.0
                    toCenter:leftCenter radius:MIN(width, height) * 0.50
                     options:NSGradientDrawsAfterEndingLocation];

    NSColor *amberGlow = ToyColor(0xF1C34A, 0.060);
    NSGradient *rightGlow = [[NSGradient alloc] initWithStartingColor:amberGlow
                                                          endingColor:ToyColor(0xF1C34A, 0.0)];
    NSPoint rightCenter = NSMakePoint(width * 0.73, height * 0.43);
    [rightGlow drawFromCenter:rightCenter radius:12.0
                     toCenter:rightCenter radius:MIN(width, height) * 0.50
                      options:NSGradientDrawsAfterEndingLocation];

    // Gentle vignette.
    NSGradient *vignette = [[NSGradient alloc] initWithStartingColor:ToyColor(0x000000, 0.0)
                                                        endingColor:ToyColor(0x000000, 0.32)];
    NSPoint center = NSMakePoint(width * 0.5, height * 0.55);
    [vignette drawFromCenter:center radius:MIN(width, height) * 0.22
                    toCenter:center radius:MAX(width, height) * 0.74
                     options:NSGradientDrawsAfterEndingLocation];

    [self drawCardShadows];

    // Header.
    NSColor *titleColor = ToyColor(0xF4F6F7, 0.97);
    NSColor *subtitleColor = ToyColor(0x8F9BA8, 1.0);
    ToyDrawText(@"TOYBOX", NSMakePoint(kStageSideMargin, height - 66.0),
                ToyTitleFont(33.0), titleColor, 3.6);
    NSSize titleSize = ToyTextSize(@"TOYBOX", ToyTitleFont(33.0), 3.6);
    NSBezierPath *titleDot = [NSBezierPath bezierPathWithOvalInRect:
        NSMakeRect(kStageSideMargin + titleSize.width - 1.0, height - 43.0, 5.0, 5.0)];
    NSShadow *dotGlow = [[NSShadow alloc] init];
    dotGlow.shadowBlurRadius = 10.0;
    dotGlow.shadowColor = ToyColor(0x81E8D3, 0.7);
    dotGlow.shadowOffset = NSMakeSize(0.0, 0.0);
    [NSGraphicsContext saveGraphicsState];
    [dotGlow set];
    [ToyColor(0x81E8D3, 0.95) setFill];
    [titleDot fill];
    [NSGraphicsContext restoreGraphicsState];

    ToyDrawText(@"Two very serious instruments.", NSMakePoint(kStageSideMargin + 1.0, height - 92.0),
                ToyBodyFont(13.0), subtitleColor, 0.15);

    [self drawStatusPillAtTop:height width:width];

    NSBezierPath *rule = [NSBezierPath bezierPath];
    [rule moveToPoint:NSMakePoint(kStageSideMargin, height - 119.0)];
    [rule lineToPoint:NSMakePoint(width - kStageSideMargin, height - 119.0)];
    rule.lineWidth = 1.0;
    [ToyColor(0xFFFFFF, 0.055) setStroke];
    [rule stroke];

    NSString *footnote = @"ALL SOUNDS SYNTHESIZED IN REAL TIME  ·  NO SAMPLES";
    NSSize footSize = ToyTextSize(footnote, ToyMonoFont(8.8, NSFontWeightRegular), 1.35);
    ToyDrawText(footnote, NSMakePoint((width - footSize.width) * 0.5, 17.0),
                ToyMonoFont(8.8, NSFontWeightRegular), ToyColor(0xFFFFFF, 0.20), 1.35);
}

- (void)drawStatusPillAtTop:(CGFloat)height width:(CGFloat)width
{
    NSFont *font = ToyMonoFont(9.2, NSFontWeightMedium);
    NSString *text = self.audioStatusText ?: @"AUDIO";
    NSSize textSize = ToyTextSize(text, font, 1.15);
    CGFloat pillWidth = [self statusPillWidth];
    CGFloat pillHeight = 25.0;
    NSRect pillRect = NSMakeRect(width - kStageSideMargin - pillWidth, height - 70.0,
                                 pillWidth, pillHeight);
    NSBezierPath *pill = [NSBezierPath bezierPathWithRoundedRect:pillRect xRadius:12.5 yRadius:12.5];
    [ToyColor(0xFFFFFF, 0.035) setFill];
    [pill fill];
    pill.lineWidth = 1.0;
    [ToyColor(0xFFFFFF, 0.065) setStroke];
    [pill stroke];

    NSColor *dotColor = self.audioOnline ? ToyColor(0x79E5CD, 1.0) : ToyColor(0xF1A14B, 1.0);
    NSRect dotRect = NSMakeRect(NSMinX(pillRect) + 13.0, NSMidY(pillRect) - 2.8, 5.6, 5.6);
    NSBezierPath *dot = [NSBezierPath bezierPathWithOvalInRect:dotRect];
    NSShadow *glow = [[NSShadow alloc] init];
    glow.shadowBlurRadius = 6.0;
    glow.shadowColor = [dotColor colorWithAlphaComponent:0.7];
    glow.shadowOffset = NSMakeSize(0.0, 0.0);
    [NSGraphicsContext saveGraphicsState];
    [glow set];
    [dotColor setFill];
    [dot fill];
    [NSGraphicsContext restoreGraphicsState];

    ToyDrawText(text, NSMakePoint(NSMinX(pillRect) + 24.0, NSMidY(pillRect) - textSize.height * 0.5),
                font, self.audioOnline ? ToyColor(0xBFE7DF, 0.80) : ToyColor(0xF2C99C, 0.88),
                1.15);
}

- (void)drawCardShadows
{
    for (NSValue *value in self.currentPanelFrames) {
        NSRect frame = value.rectValue;
        NSBezierPath *shadowPath = [NSBezierPath bezierPathWithRoundedRect:frame
                                                                   xRadius:26.0
                                                                   yRadius:26.0];
        CGContextRef context = NSGraphicsContext.currentContext.CGContext;
        CGContextSaveGState(context);
        CGContextSetShadowWithColor(context, CGSizeMake(0.0, -14.0), 34.0,
                                    ToyColor(0x000000, 0.56).CGColor);
        [ToyColor(0x05070A, 0.92) setFill];
        [shadowPath fill];
        CGContextRestoreGState(context);
    }
}

@end
