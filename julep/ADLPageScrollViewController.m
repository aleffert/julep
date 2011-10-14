//
//  ADLPageScrollViewController.m
//  julep
//
//  Created by Akiva Leffert on 10/9/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ADLPageScrollViewController.h"

#import "NSDictionary+ADLAdditions.h"

@interface ADLPageScrollViewController ()

@property (retain, nonatomic) IBOutlet UIScrollView* scrollView;
@property (retain, nonatomic) NSDictionary* activeInfos;

- (void)ensureViewControllersForSelectedIndex:(NSUInteger)index;
- (CGFloat)offsetForIndex:(NSUInteger)index;

@end

@implementation ADLPageScrollViewController

@synthesize delegate = mDelegate;
@synthesize pageInfos = mPageInfos;
@synthesize scrollView = mScrollView;
@synthesize activeInfos = mActiveInfos;
@synthesize currentPageInfo = mCurrentPageInfo;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        self.activeInfos = [NSDictionary dictionary];
    }
    return self;
}

- (void)releaseOutlets {
    self.scrollView = nil;
}

- (void)dealloc {
    self.activeInfos = nil;
    self.pageInfos = nil;
    
    [self releaseOutlets];
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.scrollView.delegate = self;
    
    if(self.pageInfos.count > 0) {
        self.scrollView.contentSize = CGSizeMake([self offsetForIndex:self.pageInfos.count + 1], self.view.frame.size.height);
        if(self.currentPageInfo != nil) {
            [self ensureViewControllersForSelectedIndex:self.currentPageIndex];
        }
    }
}

- (void)viewDidUnload {
    [super viewDidUnload];
    [self releaseOutlets];
}

- (UIViewController*)viewControllerForInfo:(id)info {
    if(info == nil) {
        return nil;
    }
    UIViewController* result = [self.activeInfos objectForKey:info];
    if(result != nil) {
        return result;
    }
    else {
        return [self.delegate viewControllerForInfo:info pageController:self];
    }
}

- (CGFloat)offsetForIndex:(NSUInteger)index {
    return self.view.frame.size.width * index;
}

- (CGAffineTransform)transformForInfo:(id)info {
    CGFloat x = [self offsetForIndex:[self.pageInfos indexOfObject:info]];
    return CGAffineTransformMakeTranslation(x, 0);
}

- (void)ensureViewControllersForSelectedIndex:(NSUInteger)index {
    // Find the controllers
    NSMutableDictionary* active = [NSMutableDictionary noCopyingMutableDictionary];
    id currentInfo = [self.pageInfos objectAtIndex:index];
    id prevInfo = nil;
    id nextInfo = nil;
    if(index > 0) {
        prevInfo = [self.pageInfos objectAtIndex:index - 1];
    }
    if(index + 1 < self.pageInfos.count) {
        nextInfo = [self.pageInfos objectAtIndex:index + 1];
    }
    UIViewController* currentController = [self viewControllerForInfo:currentInfo];
    UIViewController* prevController = [self viewControllerForInfo:prevInfo];
    UIViewController* nextController = [self viewControllerForInfo:nextInfo];
    if(prevController != nil) {
        [active setObject:prevController forKey:prevInfo];
    }
    if(currentController != nil) {
        [active setObject:currentController forKey:currentInfo];
    }
    if(nextController != nil) {
        [active setObject:nextController forKey:nextInfo];
    }
    
    // Add new views
    for(id info in active) {
        UIViewController* controller = [self.activeInfos objectForKey:info];
        if(controller == nil) {
            controller = [active objectForKey:info];
            [self addChildViewController:controller];
            [self.scrollView addSubview:controller.view];
            CGRect frame = controller.view.frame;
            controller.view.backgroundColor = [UIColor redColor];
            controller.view.frame = CGRectMake(0, 0, frame.size.width, frame.size.height);
        }
        // Update position
        controller.view.transform = [self transformForInfo:info];
    }
    
    // Remove old views
    for(id info in self.activeInfos) {
        UIViewController* controller = [active objectForKey:info];
        if(controller == nil) {
            controller = [self.activeInfos objectForKey:info];
            [controller.view removeFromSuperview];
            [controller removeFromParentViewController];
        }
    }
}

- (void)setPageInfos:(NSArray *)pageInfos {
    NSArray* infos = [pageInfos copy];
    [mPageInfos release];
    mPageInfos = infos;
    if(self.isViewLoaded) {
        self.scrollView.contentSize = CGSizeMake([self offsetForIndex:pageInfos.count], self.view.frame.size.height);
        if(self.currentPageInfo != nil) {
            [self ensureViewControllersForSelectedIndex:self.currentPageIndex];
        }
    }
}

- (void)setCurrentPageInfo:(id)currentPageInfo {
    if(currentPageInfo != mCurrentPageInfo) {
        [currentPageInfo retain];
        [mCurrentPageInfo release];
        mCurrentPageInfo = currentPageInfo;
        NSUInteger index = [self.pageInfos indexOfObject:currentPageInfo];
        CGFloat x = [self offsetForIndex:index];
        self.scrollView.contentOffset = CGPointMake(x, 0);
        [self ensureViewControllersForSelectedIndex:index];
    }
}

- (void)setCurrentPageIndex:(NSUInteger)newIndex {
    self.currentPageInfo = [self.pageInfos objectAtIndex:newIndex];
}

- (NSUInteger)currentPageIndex {
    return [self.pageInfos indexOfObject:self.currentPageInfo];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat offset = scrollView.contentOffset.x;
    CGFloat constrained = fmaxf(0, fminf(self.scrollView.contentSize.width - 1, offset));
    NSUInteger index = floorf(constrained / self.scrollView.frame.size.width);
    if(index != self.currentPageIndex) {
        // Won't ever lose it because it's owned by pageInfos
        [mCurrentPageInfo release];
        mCurrentPageInfo = [[self.pageInfos objectAtIndex:index] retain];
        [self ensureViewControllersForSelectedIndex:index];
        [self.delegate pageController:self changedSelectionTo:mCurrentPageInfo];
    }
}

@end
