#import "ToyPanelView.h"

#import "ToyTheme.h"

static const CGFloat kPanelCornerRadius = 26.0;
static const CGFloat kPanelHeaderHeight = 104.0;
static const CGFloat kPanelFooterHeight = 46.0;

@interface ToyPanelView ()
@property (nonatomic, copy) NSString *titleText;
@property (nonatomic, copy) NSString *subtitleText;
@property (nonatomic, copy) NSString *numberText;
@property (nonatomic, copy) NSString *hintText;
@property (nonatomic, strong) NSColor *accentColor;
@property (nonatomic, strong, readwrite) NSView *toyView;
@end

@implementation ToyPanelView

- (instancetype)initWithTitle:(NSString *)title
                     subtitle:(NSString *)subtitle
                       number:(NSString *)number
                         hint:(NSString *)hint
                       accent:(NSColor *)accent
                      toyView:(NSView *)toyView
{
    self = [super initWithFrame:NSZeroRect];
    if (self) {
        _titleText = [title copy];
        _subtitleText = [subtitle copy];
        _numberText = [number copy];
        _hintText = [hint copy];
        _accentColor = accent;
        _toyView = toyView;
        [self addSubview:toyView];
        self.autoresizesSubviews = NO;
    }
    return self;
}

- (BOOL)isOpaque
{
    return NO;
}

- (void)setFrameSize:(NSSize)newSize
{
    [super setFrameSize:newSize];
    [self layoutToyView];
    [self setNeedsDisplay:YES];
}

- (void)layoutToyView
{
    CGFloat width = NSWidth(self.bounds);
    CGFloat height = NSHeight(self.bounds);
    CGFloat toyHeight = MAX(60.0, height - kPanelHeaderHeight - kPanelFooterHeight);
    self.toyView.frame = NSMakeRect(12.0, kPanelFooterHeight - 4.0, width - 24.0, toyHeight);
}

- (void)drawRect:(NSRect)dirtyRect
{
    (void)dirtyRect;
    [super drawRect:dirtyRect];

    NSRect bounds = self.bounds;
    CGFloat width = NSWidth(bounds);
    CGFloat height = NSHeight(bounds);
    NSRect cardRect = NSInsetRect(bounds, 0.5, 0.5);
    NSBezierPath *card = [NSBezierPath bezierPathWithRoundedRect:cardRect
                                                        xRadius:kPanelCornerRadius
                                                        yRadius:kPanelCornerRadius];

    NSGradient *surface = [[NSGradient alloc] initWithStartingColor:ToyColor(0x1A212A, 0.96)
                                                       endingColor:ToyColor(0x0D1116, 0.985)];
    [surface drawInBezierPath:card angle:-90.0];

    [NSGraphicsContext saveGraphicsState];
    [card addClip];

    // Glassy sheen along the top edge.
    NSGradient *sheen = [[NSGradient alloc] initWithStartingColor:ToyColor(0xFFFFFF, 0.045)
                                                     endingColor:ToyColor(0xFFFFFF, 0.0)];
    [sheen drawInRect:NSMakeRect(0.0, height - 170.0, width, 170.0) angle:-90.0];

    // Instrument-colored halo behind the toy.
    NSColor *inner = [self.accentColor colorWithAlphaComponent:0.085];
    NSColor *outer = [self.accentColor colorWithAlphaComponent:0.0];
    NSGradient *halo = [[NSGradient alloc] initWithStartingColor:inner endingColor:outer];
    NSPoint haloCenter = NSMakePoint(width * 0.5, height * 0.43);
    [halo drawFromCenter:haloCenter radius:10.0
                toCenter:haloCenter radius:MIN(width, height) * 0.50
                 options:NSGradientDrawsAfterEndingLocation];

    [NSGraphicsContext restoreGraphicsState];

    card.lineWidth = 1.0;
    [ToyColor(0xFFFFFF, 0.075) setStroke];
    [card stroke];

    // Inner top rim.
    NSBezierPath *rim = [NSBezierPath bezierPath];
    [rim moveToPoint:NSMakePoint(kPanelCornerRadius, height - 1.2)];
    [rim lineToPoint:NSMakePoint(width - kPanelCornerRadius, height - 1.2)];
    rim.lineWidth = 1.0;
    [ToyColor(0xFFFFFF, 0.05) setStroke];
    [rim stroke];

    // Header labels.
    NSColor *titleColor = ToyColor(0xF1F4F6, 0.94);
    NSColor *subtitleColor = ToyColor(0x909BA8, 1.0);

    CGFloat titleY = height - 59.0;
    NSBezierPath *dot = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(28.0, titleY + 6.0, 7.0, 7.0)];
    NSShadow *dotGlow = [[NSShadow alloc] init];
    dotGlow.shadowBlurRadius = 8.0;
    dotGlow.shadowColor = [self.accentColor colorWithAlphaComponent:0.6];
    dotGlow.shadowOffset = NSMakeSize(0.0, 0.0);
    [NSGraphicsContext saveGraphicsState];
    [dotGlow set];
    [self.accentColor setFill];
    [dot fill];
    [NSGraphicsContext restoreGraphicsState];

    ToyDrawText(self.titleText, NSMakePoint(43.0, titleY),
                ToyTitleFont(14.5), titleColor, 2.6);
    ToyDrawText(self.subtitleText, NSMakePoint(28.0, height - 83.0),
                ToyBodyFont(12.0), subtitleColor, 0.1);

    NSSize indexSize = ToyTextSize(self.numberText, ToyMonoFont(10.0, NSFontWeightMedium), 1.2);
    ToyDrawText(self.numberText,
                NSMakePoint(width - 28.0 - indexSize.width, titleY + 1.0),
                ToyMonoFont(10.0, NSFontWeightMedium), ToyColor(0xFFFFFF, 0.23), 1.2);

    NSBezierPath *divider = [NSBezierPath bezierPath];
    [divider moveToPoint:NSMakePoint(26.0, height - 99.0)];
    [divider lineToPoint:NSMakePoint(width - 26.0, height - 99.0)];
    divider.lineWidth = 1.0;
    [ToyColor(0xFFFFFF, 0.055) setStroke];
    [divider stroke];

    // Footer hint.
    NSBezierPath *hintDot = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(28.0, 26.0, 4.0, 4.0)];
    [[self.accentColor colorWithAlphaComponent:0.70] setFill];
    [hintDot fill];
    ToyDrawText(self.hintText, NSMakePoint(39.0, 20.0),
                ToySmallFont(9.6), [self.accentColor colorWithAlphaComponent:0.72], 1.35);
}

@end
