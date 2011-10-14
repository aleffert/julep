//
//  ADLUITabViewController.m
//  julep
//
//  Created by Akiva Leffert on 10/8/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ADLUITabViewController.h"
#import "ADLUIScrollView.h"
#import "ADLUITabView.h"
#import "ADLViewManipulator.h"

@interface ADLUITabViewController ()

@property (retain, nonatomic) IBOutlet ADLUIScrollView* scrollView;
@property (retain, nonatomic) ADLTabController* agnostic;

@end

const static CGFloat kADLUITabWidth = 181;
const static CGFloat kADLUITabHeight = 28.;


@implementation ADLUITabViewController

@synthesize scrollView = mScrollView;
@synthesize agnostic = mAgnostic;
@synthesize viewManipulator = mViewManipulator;

- (id)initWithDataSource:(id <ADLTabControllerDataSource>)dataSource {
    self = [self initWithNibName:nil bundle:nil];
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
    return self.scrollView;
}

- (id <ADLTabView>)makeTabViewForTabController:(ADLTabController*)tabController {
    ADLUITabView* tabView = [[ADLUITabView alloc] initWithFrame:CGRectMake(0, 0, kADLUITabWidth, kADLUITabHeight)];
    
    return [tabView autorelease];
}

- (void)updateSizeForContentWidth:(CGFloat)width {
    width = MAX(width, self.scrollView.frame.size.width);
    
    CGRect frame = self.view.frame;
    frame.size.height = kADLUITabHeight;
    self.view.frame = frame;
    
    UIView* bodyView = self.scrollView;
    CGRect bodyFrame = bodyView.frame;
    bodyFrame.size.height = kADLUITabHeight;
    bodyView.frame = bodyFrame;
    self.scrollView.contentSize = CGSizeMake(width, bodyFrame.size.height);
}

- (void)animateInTabView:(id <ADLTabView>)tabView {
    ADLUITabView* uiTabView = (ADLUITabView*)tabView;
    CGRect endFrame = [self.viewManipulator frameOfView:tabView];
    CGRect startFrame = endFrame;
    startFrame.origin.y += self.view.frame.size.height;

    CABasicAnimation* animation = [CABasicAnimation animationWithKeyPath:@"frame"];
    animation.fromValue = [NSValue valueWithCGRect:startFrame];
    animation.toValue = [NSValue valueWithCGRect:endFrame];
    
    [uiTabView.layer addAnimation:animation forKey:@"animateTabIn"];
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
