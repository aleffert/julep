//
//  ADLUIViewManipulator.m
//  julep
//
//  Created by Akiva Leffert on 10/7/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ADLUIViewManipulator.h"

@implementation ADLUIViewManipulator

- (void)orderViewFront:(id <ADLView>)view {
    UIView* uiView = (UIView*)view;
    [uiView.superview bringSubviewToFront:uiView];
}

- (void)addSubview:(id <ADLView>)subview toView:(id <ADLView>)parentView {
    UIView* uiSubview = (UIView*)subview;
    UIView* uiParentView = (UIView*)parentView;
    [uiParentView addSubview:uiSubview];
}

- (CGRect)frameOfView:(id <ADLView>)view {
    UIView* uiView = (UIView*)view;
    return uiView.frame;
}
- (void)setFrame:(CGRect)frame ofView:(id <ADLView>)view {
    UIView* uiView = (UIView*)view;
    uiView.frame = frame;
}

- (CGSize)contentSizeOfScrollView:(id <ADLScrollView>)scrollView {
    UIScrollView* uiScrollView = (UIScrollView*)scrollView;
    return uiScrollView.contentSize;
}

- (void)setContentSize:(CGSize)size ofScrollView:(id <ADLScrollView>)scrollView {
    UIScrollView* uiScrollView = (UIScrollView*)scrollView;
    uiScrollView.contentSize = size;
}

- (void)performAnimations:(void (^)(void))animations duration:(NSTimeInterval)duration {
    [UIView animateWithDuration:duration animations:animations];
}

- (void)performAnimations:(void (^)(void))animations completion:(void (^)(void))completion duration:(NSTimeInterval)duration {
    [UIView animateWithDuration:duration animations:animations completion:^(BOOL finished) {
        completion();
    }];
}


@end
