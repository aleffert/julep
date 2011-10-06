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
#import "ADLViewManipulator.h"

@interface ADLNSTabViewController ()

@property (retain, nonatomic) IBOutlet ADLNSScrollView* scrollView;
@property (retain, nonatomic) ADLTabController* agnostic;

@end

const static CGFloat kADLNSTabWidth = 181;
const static CGFloat kADLNSTabHeight = 28.;

@implementation ADLNSTabViewController

@synthesize scrollView = mScrollView;
@synthesize agnostic = mAgnostic;
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
    
    [super dealloc];
}

- (id <ADLView>)bodyView {
    return self.scrollView.documentView;
}

- (id <ADLTabView>)makeTabViewForTabController:(ADLTabController*)tabController {
    ADLNSTabView* tabView = [[ADLNSTabView alloc] initWithFrame:NSMakeRect(0, 0, kADLNSTabWidth, kADLNSTabHeight)];
    
    return [tabView autorelease];
}

- (void)updateSizeForContentWidth:(CGFloat)width {
    width = MAX(width, self.scrollView.frame.size.width);
    
    CGRect frame = self.view.frame;
    CGFloat currentTop = NSMaxY(frame);
    frame.origin.y = currentTop - kADLNSTabHeight;
    frame.size.height = kADLNSTabHeight;
    self.view.frame = frame;
    
    NSView* bodyView = self.scrollView.documentView;
    CGRect bodyFrame = bodyView.frame;
    bodyFrame.size.width = width;
    bodyFrame.size.height = kADLNSTabHeight;
    bodyView.frame = bodyFrame;
}

- (void)animateInTabView:(id <ADLTabView>)tabView {
    CGRect endFrame = [self.viewManipulator frameOfView:tabView];
    CGRect startFrame = endFrame;
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
