#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface ToyPanelView : NSView

- (instancetype)initWithTitle:(NSString *)title
                     subtitle:(NSString *)subtitle
                       number:(NSString *)number
                         hint:(NSString *)hint
                       accent:(NSColor *)accent
                      toyView:(NSView *)toyView;

@property (nonatomic, strong, readonly) NSView *toyView;

@end

NS_ASSUME_NONNULL_END
