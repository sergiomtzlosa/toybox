#import "ToyRecordButton.h"

#import "ToyTheme.h"

@implementation ToyRecordButton {
    NSTrackingArea *_trackingArea;
    BOOL _hovering;
}

- (instancetype)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        _elapsedText = @"00:00";
        self.bordered = NO;
        self.buttonType = NSButtonTypeMomentaryChange;
        self.focusRingType = NSFocusRingTypeNone;
        self.title = @"";
        self.toolTip = @"Record the mixed performance to ~/Music/Toybox Recordings";
        self.accessibilityLabel = @"Record sound";
        self.accessibilityHelp = @"Saves everything you play, including the room reverb, to a WAV file in your Music folder.";
    }
    return self;
}

- (BOOL)isOpaque
{
    return NO;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event
{
    (void)event;
    return YES;
}

- (void)setRecording:(BOOL)recording
{
    if (_recording == recording) {
        return;
    }
    _recording = recording;
    self.accessibilityLabel = recording ? @"Stop recording" : @"Record sound";
    self.toolTip = recording
        ? @"Stop and save this performance"
        : @"Record the mixed performance to ~/Music/Toybox Recordings";
    [self setNeedsDisplay:YES];
}

- (void)setElapsedText:(NSString *)elapsedText
{
    _elapsedText = [elapsedText copy] ?: @"00:00";
    [self setNeedsDisplay:YES];
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

- (void)mouseEntered:(NSEvent *)event
{
    (void)event;
    _hovering = YES;
    [self setNeedsDisplay:YES];
}

- (void)mouseExited:(NSEvent *)event
{
    (void)event;
    _hovering = NO;
    [self setNeedsDisplay:YES];
}

- (void)resetCursorRects
{
    [super resetCursorRects];
    [self addCursorRect:self.bounds cursor:NSCursor.pointingHandCursor];
}

- (void)drawRect:(NSRect)dirtyRect
{
    (void)dirtyRect;

    NSRect pillRect = NSInsetRect(self.bounds, 0.5, 0.5);
    NSBezierPath *pill = [NSBezierPath bezierPathWithRoundedRect:pillRect
                                                        xRadius:NSHeight(pillRect) * 0.5
                                                        yRadius:NSHeight(pillRect) * 0.5];

    NSColor *fill = self.isRecording
        ? ToyColor(0xF25A4D, 0.13)
        : ToyColor(0xFFFFFF, _hovering ? 0.060 : 0.035);
    [fill setFill];
    [pill fill];

    pill.lineWidth = 1.0;
    NSColor *border = self.isRecording
        ? ToyColor(0xF36A5B, 0.48)
        : ToyColor(0xFFFFFF, _hovering ? 0.13 : 0.07);
    [border setStroke];
    [pill stroke];

    NSColor *dotColor = self.isRecording ? ToyColor(0xFF7164, 1.0) : ToyColor(0xE95A50, 0.92);
    NSRect dotRect = NSMakeRect(11.5, NSMidY(self.bounds) - 3.0, 6.0, 6.0);
    NSBezierPath *dot = [NSBezierPath bezierPathWithOvalInRect:dotRect];
    if (self.isRecording) {
        NSShadow *glow = [[NSShadow alloc] init];
        glow.shadowBlurRadius = 7.0;
        glow.shadowColor = ToyColor(0xFF5C50, 0.8);
        glow.shadowOffset = NSMakeSize(0.0, 0.0);
        [NSGraphicsContext saveGraphicsState];
        [glow set];
        [dotColor setFill];
        [dot fill];
        [NSGraphicsContext restoreGraphicsState];
    } else {
        [dotColor setFill];
        [dot fill];
    }

    NSFont *font = ToyMonoFont(8.6, NSFontWeightSemibold);
    NSColor *textColor = self.isRecording
        ? ToyColor(0xFFD7D2, 0.96)
        : ToyColor(0xD9E2E6, 0.72);

    if (self.isRecording) {
        ToyDrawText(@"STOP", NSMakePoint(24.0, NSMidY(self.bounds) - 5.3),
                    font, textColor, 1.0);
        NSSize timeSize = ToyTextSize(self.elapsedText, font, 0.6);
        ToyDrawText(self.elapsedText,
                    NSMakePoint(NSWidth(self.bounds) - 12.0 - timeSize.width,
                                NSMidY(self.bounds) - 5.3),
                    font, ToyColor(0xFFA79D, 0.90), 0.6);
    } else {
        ToyDrawText(@"RECORD", NSMakePoint(24.0, NSMidY(self.bounds) - 5.3),
                    font, textColor, 1.1);
    }
}

@end
