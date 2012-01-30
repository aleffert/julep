//
//  ADLPileViewController.m
//  julep
//
//  Created by Akiva Leffert on 9/16/11.
//

#import <QuartzCore/QuartzCore.h>

#import "ADLPileViewController.h"

#import "ADLColor.h"
#import "ADLColorView.h"
#import "ADLShadowView.h"
#import "ADLFloatUtilities.h"

#import "NSShadow+ADLExtensions.h"

#define kADLShadowInsets 8

@interface ADLPileSlide : NSObject {
    BOOL mAbort;
    NSViewController* mBehindViewController;
    NSViewController* mSlidingViewController;
    CGFloat mFromValue;
    CGFloat mToValue;
    CGFloat mGoalAmount;
    NSView* mParentView;
    ADLShadowView* mShadowView;
}

@property (assign, nonatomic) BOOL abort;
@property (retain, nonatomic) NSViewController* behindViewController;
@property (retain, nonatomic) NSViewController* slidingViewController;
@property (retain, nonatomic) NSView* parentView;

@property (retain, nonatomic) ADLShadowView* shadowView;

@property (assign, nonatomic) CGFloat goalAmount;

@property (assign, nonatomic) CGFloat fromValue;
@property (assign, nonatomic) CGFloat toValue;

+ (ADLPileSlide*)slide:(NSViewController*)slidingViewController behind:(NSViewController*)behindViewController inside:(NSView*)parentView;

- (void)slideToAmount:(CGFloat)slideAmount;

@end

void ADLWithAnimationsDisabled(void(^block)(void));

void ADLWithAnimationsDisabled(void(^block)(void)) {
    [[NSAnimationContext currentContext] setDuration:0];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    block();
    [CATransaction commit];
}


@implementation ADLPileSlide

@synthesize abort = mAbort;
@synthesize behindViewController = mBehindViewController;
@synthesize fromValue = mFromValue;
@synthesize goalAmount = mGoalAmount;
@synthesize parentView = mParentView;
@synthesize shadowView = mshadowView;
@synthesize slidingViewController = mSlidingViewController;
@synthesize toValue = mToValue;

+ (ADLPileSlide*)slide:(NSViewController*)slidingViewController behind:(NSViewController*)behindViewController inside:(NSView*)parentView {
    ADLPileSlide* pileSlide = [[self alloc] init];
    pileSlide.behindViewController = behindViewController;
    pileSlide.parentView = parentView;
    pileSlide.slidingViewController = slidingViewController;
    
    return [pileSlide autorelease];
}

- (void)dealloc {
    self.behindViewController = nil;
    self.parentView = nil;
    self.slidingViewController = nil;
    [super dealloc];
}


- (void)startSlide {
    ADLWithAnimationsDisabled(^(void) {
        [self.parentView addSubview:self.slidingViewController.view positioned:NSWindowAbove relativeTo:nil];
        if(self.behindViewController != nil) {
            [self.behindViewController.view removeFromSuperview];
            [self.parentView addSubview:self.behindViewController.view positioned:NSWindowBelow relativeTo:self.slidingViewController.view];
        }
        CGFloat width = self.parentView.frame.size.width;
        CGFloat height = self.parentView.frame.size.height;
        NSView* behindView = self.behindViewController.view;
        NSView* slidingView = self.slidingViewController.view;
        if(behindView != nil) {
            // if behind view is nil, sliding view must be the currently visible view
            // so we don't need to change it
            slidingView.frame = NSMakeRect(self.fromValue, 0, width, height);
        }
        behindView.frame = NSMakeRect(0, 0, width, height);
        self.shadowView.frame = NSInsetRect(self.slidingViewController.view.frame, -kADLShadowInsets, 0);
        [self.parentView addSubview:self.shadowView  positioned:NSWindowBelow relativeTo:self.slidingViewController.view];
    });
}

- (void)slideToAmount:(CGFloat)slideAmount {
    ADLWithAnimationsDisabled(^(void) {
        CGFloat scaledAmount = (slideAmount + 1) / 2;
        NSView* slidingView = self.slidingViewController.view;
        slidingView.frameOrigin = NSMakePoint(floor(self.toValue * scaledAmount + self.fromValue * (1 - scaledAmount)), 0);
        self.shadowView.frame = NSInsetRect(self.slidingViewController.view.frame, -kADLShadowInsets, 0);
    });
}

- (void)cleanup {
    ADLWithAnimationsDisabled(^(void) {
        [self.shadowView removeFromSuperview];
        self.shadowView = nil;
    });
}

@end

@interface ADLPileViewController ()

@property (retain, nonatomic) ADLPileSlide* pileSlide;
@property (retain, nonatomic) ADLShadowView* shadowView;

@end

@implementation ADLPileViewController

@synthesize currentViewController = mCurrentViewController;
@synthesize delegate = mDelegate;
@synthesize nextViewController = mNextViewController;
@synthesize pileSlide = mPileSlide;
@synthesize prevViewController = mPrevViewController;

@synthesize shadowView = mShadowView;
@synthesize swipeGestureOptions = mSwipeGestureOptions;

- (void)dealloc {
    self.delegate = nil;
    self.nextViewController = nil;
    self.prevViewController = nil;
    self.currentViewController = nil;
    self.pileSlide = nil;
    
    [super dealloc];
}

- (void)setCurrentViewController:(NSViewController*)viewController {
    if(viewController != mCurrentViewController) {
        [mCurrentViewController.view removeFromSuperview];
        [viewController retain];
        [mCurrentViewController release];
        mCurrentViewController = viewController;
        [self.view addSubview: viewController.view];
        viewController.view.frame = self.view.bounds;
        viewController.nextResponder = self;
    }
}

- (BOOL)wantsScrollEventsForSwipeTrackingOnAxis:(NSEventGestureAxis)axis {
    return axis == NSEventGestureAxisHorizontal;
}

- (void)finishUpSlide:(BOOL)succeeded {
    ADLWithAnimationsDisabled(^(void) {
        
        if(succeeded) {
            if(self.pileSlide.goalAmount < 0) {
                // Moved next in
                [self.prevViewController.view removeFromSuperview];
                self.prevViewController = self.currentViewController;
                self.currentViewController = self.nextViewController;
                self.nextViewController = [self.delegate nextViewControllerAfterActivating:self.currentViewController inPile:self];
            }
            else if(self.pileSlide.goalAmount > 0) {
                // Moved prev in
                [self.nextViewController.view removeFromSuperview];
                self.nextViewController = self.currentViewController;
                self.currentViewController = self.prevViewController;
                self.prevViewController = [self.delegate prevViewControllerAfterActivating:self.currentViewController inPile:self];
            }
            else {
                // else make sure we move back to the beginning
                NSView* view = self.currentViewController.view;
                view.frameOrigin = NSZeroPoint;
            }
        }
        else {
            // And get rid of any extra views on the side
            [self.nextViewController.view removeFromSuperview];
            [self.prevViewController.view removeFromSuperview];
        }

    });
}

- (void)startTrackingSwipeWithEvent:(NSEvent*)event {
    CGFloat minThreshold = self.nextViewController == nil ? 0 : -1;
    CGFloat maxThreshold = self.prevViewController == nil ? 0 : 1;
    [event trackSwipeEventWithOptions:self.swipeGestureOptions dampenAmountThresholdMin:minThreshold max:maxThreshold usingHandler: ^(CGFloat gestureAmount, NSEventPhase phase, BOOL isComplete, BOOL *stop) {
        if(self.pileSlide.abort) {
            [self finishUpSlide:YES];
            self.pileSlide = nil;
            *stop = YES;
            return;
        }
        else if(self.pileSlide == nil && ((phase == NSEventPhaseBegan) || (phase == NSEventPhaseChanged) || (phase == NSEventPhaseNone))) {
            if(gestureAmount < 0) {
                if(self.nextViewController != nil) {
                    self.pileSlide = [ADLPileSlide slide:self.nextViewController behind:self.currentViewController inside:self.view];
                    self.pileSlide.fromValue = 0;
                    self.pileSlide.toValue = 2 * self.view.frame.size.width;
                    self.pileSlide.goalAmount = -1;
                }
            }
            else if(gestureAmount > 0) {
                if(self.prevViewController != nil) {
                    self.pileSlide = [ADLPileSlide slide:self.currentViewController behind:self.prevViewController inside:self.view];
                }
            }
            if(fabsf(gestureAmount) > 0 && self.pileSlide == nil) {
                self.pileSlide = [ADLPileSlide slide:self.currentViewController behind:nil inside:self.view];
            }
            
            if(self.pileSlide.slidingViewController != self.nextViewController) {
                //This is case is different because we're sliding the currently visible view
                self.pileSlide.fromValue = -self.view.frame.size.width;
                self.pileSlide.toValue = self.view.frame.size.width;
                if(self.pileSlide.behindViewController == nil) {
                    // If behind view is nil then we're not actually revealing anything
                    self.pileSlide.goalAmount = 0;
                }
                else {
                    self.pileSlide.goalAmount = 1;
                }
            }
            self.pileSlide.shadowView = self.shadowView;
            [self.pileSlide startSlide];
        }
        
        [self.pileSlide slideToAmount:gestureAmount];
        if(isComplete) {
            BOOL succeeded = ADLFloatsAlmostEqual(self.pileSlide.goalAmount, gestureAmount);
            [self.pileSlide cleanup];
            [self finishUpSlide:succeeded];
            self.pileSlide = nil;
        }
        else if(self.pileSlide != nil) {
            // If we swapped directions, cancel the current slide
            BOOL nextToPrev = self.pileSlide.goalAmount < 0 && gestureAmount > 0;
            BOOL prevToNext = self.pileSlide.goalAmount > 0 && gestureAmount < 0;
            BOOL noneToPrev = ADLFloatsAlmostEqual(0, self.pileSlide.goalAmount) && gestureAmount > 0 && self.prevViewController != nil;
            BOOL noneToNext = ADLFloatsAlmostEqual(0, self.pileSlide.goalAmount) && gestureAmount < 0 && self.nextViewController != nil;
            
            ADLWithAnimationsDisabled(^(void) {
                if(nextToPrev) {
                    [self.nextViewController.view removeFromSuperview];
                }
                else if(prevToNext) {
                    [self.prevViewController.view removeFromSuperview];
                }
            });
            
            if(nextToPrev || prevToNext || noneToPrev || noneToNext) {
                [self.pileSlide cleanup];
                self.pileSlide = nil;
            }
        }
    }];
}

- (void)scrollWheel:(NSEvent *)event {
//    if([NSEvent isSwipeTrackingFromScrollEventsEnabled]) {
//        BOOL inCorrectPhase = event.phase == NSEventPhaseBegan || event.phase == NSEventPhaseChanged;
//        if(self.pileSlide == nil && inCorrectPhase) {
//            [self startTrackingSwipeWithEvent:event];
//        }
//        else if(self.pileSlide != nil && !self.pileSlide.abort) {
//            // New gesture interaction while we're tracking. Abort the current operation
//            self.pileSlide.abort = YES;
//        }
//    }
}

- (void)viewDidLoad {
    NSView* backgroundView = nil;
    if([self.delegate respondsToSelector:@selector(backgroundViewForPile:)]) {
        backgroundView = [self.delegate backgroundViewForPile:self];
    }
    if(backgroundView != nil) {
        [self.view addSubview:backgroundView positioned:NSWindowBelow relativeTo:nil];
    }
    self.shadowView = [[[ADLShadowView alloc] init] autorelease];
    self.shadowView.shadow = [NSShadow standardShadow];
    self.shadowView.insets = NSEdgeInsetsMake(0, kADLShadowInsets, 0, kADLShadowInsets);
}

- (void)loadView {
    [super loadView];
    [self viewDidLoad];
}

@end
