//
//  ADLPileViewController.h
//  julep
//
//  Created by Akiva Leffert on 9/16/11.
//

#import <Cocoa/Cocoa.h>

@protocol ADLPileViewControllerDelegate;

@class ADLPileSlide;

@interface ADLPileViewController : NSViewController

@property (assign, nonatomic) id <ADLPileViewControllerDelegate> delegate;

@property (retain, nonatomic) NSViewController* currentViewController;
@property (retain, nonatomic) NSViewController* nextViewController;
@property (retain, nonatomic) NSViewController* prevViewController;

@property (assign, nonatomic) NSEventSwipeTrackingOptions swipeGestureOptions;

@end

@protocol ADLPileViewControllerDelegate <NSObject>

- (NSViewController*)prevViewControllerAfterActivating:(NSViewController*)newCurrentViewController inPile:(ADLPileViewController*)pileViewController;
- (NSViewController*)nextViewControllerAfterActivating:(NSViewController*)newCurrentViewController inPile:(ADLPileViewController*)pileViewController;

@optional

// Called only when the pile view loads
- (NSView*)backgroundViewForPile:(ADLPileViewController*)pileController;

@end