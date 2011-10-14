//
//  ADLPageScrollViewController.h
//  julep
//
//  Created by Akiva Leffert on 10/9/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol ADLPageScrollViewControllerDelegate;

@interface ADLPageScrollViewController : UIViewController <UIScrollViewDelegate>

@property (assign, nonatomic) id <ADLPageScrollViewControllerDelegate> delegate;
@property (copy, nonatomic) NSArray* pageInfos;
@property (assign, nonatomic) NSUInteger currentPageIndex;
@property (assign, nonatomic) id currentPageInfo;

@end

@protocol ADLPageScrollViewControllerDelegate <NSObject>

- (UIViewController*)viewControllerForInfo:(id)info pageController:(ADLPageScrollViewController*)pageController;
- (void)pageController:(ADLPageScrollViewController*)pageController changedSelectionTo:(id)info;

@end
