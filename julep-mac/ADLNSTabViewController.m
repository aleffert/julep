//
//  ADLNSTabViewController.m
//  julep
//
//  Created by Akiva Leffert on 8/22/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ADLNSTabViewController.h"

#import "ADLNSTabView.h"
#import "ADLNSScrollView.h"
#import "ADLShadowView.h"
#import "ADLViewManipulator.h"
#import "NSShadow+ADLExtensions.h"

@interface ADLNSTabViewController ()

@property (retain, nonatomic) IBOutlet NSView* bodyView;
@property (retain, nonatomic) IBOutlet ADLNSScrollView* scrollView;
@property (retain, nonatomic) ADLTabController* agnostic;

@end

const static CGFloat kADLNSTabWidth = 149.;
const static CGFloat kADLNSTabHeight = 29.;

@interface ADLNSTabViewController ()

@property (retain, nonatomic) id <ADLView> shadowView;

@end

@interface ADLNSTabViewController (ADLCast)

@property (retain, nonatomic) ADLShadowView* shadowView;

@end

@implementation ADLNSTabViewController

@synthesize scrollView = mScrollView;
@synthesize bodyView = mBodyView;
@synthesize agnostic = mAgnostic;
@synthesize shadowView = mShadowView;
@synthesize viewManipulator = mViewManipulator;

- (id)initWithDataSource:(id <ADLTabControllerDataSource>)dataSource {
    self = [self initWithNibName:@"ADLNSTabViewController" bundle:nil];
    if (self) {
        self.agnostic = [[[ADLTabController alloc] initWithDelegate:self dataSource:dataSource] autorelease];
    }
    
    return self;
}

- (void)dealloc {
    self.agnostic = nil;
    self.scrollView = nil;
    self.bodyView = nil;
    self.shadowView = nil;
    self.viewManipulator = nil;
    
    [super dealloc];
}

- (void)viewDidLoad {
    NSRect bodyFrame = self.bodyView.frame;
    NSRect shadowFrame = NSMakeRect(0, -5, bodyFrame.size.width, 10);
    ADLShadowView* shadowView = [[[ADLShadowView alloc] initWithFrame:shadowFrame] autorelease];
    shadowView.autoresizingMask = NSViewMaxYMargin | NSViewWidthSizable;
    shadowView.shadow = [NSShadow standardShadow];
    shadowView.shadow.shadowBlurRadius = 2;
    shadowView.shadow.shadowColor = [NSColor colorWithDeviceWhite:0 alpha:.2];

    shadowView.insets = NSEdgeInsetsMake(5, 0, 0, 0);
    self.shadowView = (id <ADLView>)shadowView;
    self.scrollView.hasHorizontalScroller = YES;
    self.scrollView.horizontalScroller.hidden = YES;
    
}

- (void)loadView {
    [super loadView];
    [self viewDidLoad];
}

- (NSView*)makeTabViewForTabController:(ADLTabController*)tabController {
    ADLNSTabView* tabView = [[ADLNSTabView alloc] initWithFrame:NSMakeRect(0, 0, kADLNSTabWidth, kADLNSTabHeight)];
    
    return [tabView autorelease];
}

- (void)makeTabVisible:(id <ADLTabView>)tabView {
    ADLNSTabView* nsTabView = (ADLNSTabView*)tabView;
    NSRect tabRect = [nsTabView convertRect:nsTabView.bounds toView:self.scrollView.contentView];
    NSRect visibleBounds = self.scrollView.contentView.documentVisibleRect;
    NSRect intersection = NSIntersectionRect(tabRect, visibleBounds);
    [NSAnimationContext beginGrouping];
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext* context) {
        context.duration = .3;
        context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        if(intersection.size.width < tabRect.size.width) {
            if(NSPointInRect(visibleBounds.origin, NSInsetRect(tabRect, -2, -2))) {
                [self.scrollView.contentView.animator setBoundsOrigin:tabRect.origin];
            }
            else {
                NSPoint newPoint = NSMakePoint(NSMaxX(tabRect) - visibleBounds.size.width, tabRect.origin.y);
                [self.scrollView.contentView.animator setBoundsOrigin:newPoint];
            }
        }
    } completionHandler:NULL];
}

- (void)updateSizeForContentWidth:(CGFloat)width {
    width = MAX(width, self.scrollView.frame.size.width);
    
    NSRect frame = self.view.frame;
    CGFloat currentTop = NSMaxY(frame);
    frame.origin.y = currentTop - kADLNSTabHeight;
    frame.size.height = kADLNSTabHeight;
    self.view.frame = frame;
    
    NSView* bodyView = self.bodyView;
    NSRect bodyFrame = bodyView.frame;
    bodyFrame.size.width = width;
    bodyFrame.size.height = kADLNSTabHeight;
    bodyView.frame = bodyFrame;
}

- (void)animateInTabView:(id <ADLTabView>)tabView {
    NSRect endFrame = NSRectFromCGRect([self.viewManipulator frameOfView:tabView]);
    NSRect startFrame = endFrame;
    startFrame.origin.y -= self.view.frame.size.height;
    NSViewAnimation* animation = [[NSViewAnimation alloc] initWithViewAnimations:
                                  [NSArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys:
        tabView, NSViewAnimationTargetKey,
        [NSValue valueWithRect:startFrame], NSViewAnimationStartFrameKey,
        [NSValue valueWithRect:endFrame], NSViewAnimationEndFrameKey,
        NSViewAnimationFadeInEffect, NSViewAnimationEffectKey,
      nil]]];
    animation.duration = .2;
    
    [animation startAnimation];
    [animation release];
}

- (void)animateOutTabView:(id <ADLTabView>)tabView {
    id <ADLViewManipulator> viewManipulator = self.viewManipulator;
    CGRect newFrame = [viewManipulator frameOfView:tabView];
    newFrame.origin.y -= self.view.frame.size.height;
    [viewManipulator performAnimations:^(void) {
        [viewManipulator setFrame:newFrame ofView:tabView];
    } completion:^(void) {
        [tabView removeFromSuperview];
    } duration:.2];
}

@end
