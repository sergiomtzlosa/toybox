#import <Cocoa/Cocoa.h>

@class ToyPanelView;
@class ToyRecordButton;

NS_ASSUME_NONNULL_BEGIN

@interface StageView : NSView

@property (nonatomic, copy) NSArray<ToyPanelView *> *panels;
@property (nonatomic, copy) NSString *audioStatusText;
@property (nonatomic, assign) BOOL audioOnline;
@property (nonatomic, strong, readonly) ToyRecordButton *recordButton;

@end

NS_ASSUME_NONNULL_END
