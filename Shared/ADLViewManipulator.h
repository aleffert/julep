//
//  ADLViewManipulator.h
//  julep
//
//  Created by Akiva Leffert on 8/22/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol ADLScrollView;
@protocol ADLView;

@protocol ADLViewManipulator <NSObject>

- (void)orderViewFront:(id <ADLView>)view;
- (void)addSubview:(id <ADLView>)subview toView:(id <ADLView>)parentView;

- (CGRect)frameOfView:(id <ADLView>)view;
- (void)setFrame:(CGRect)frame ofView:(id <ADLView>)view;

- (CGSize)contentSizeOfScrollView:(id <ADLScrollView>)scrollView;
- (void)setContentSize:(CGSize)size ofScrollView:(id <ADLScrollView>)scrollView;

- (void)performAnimations:(void (^)(void))animations duration:(NSTimeInterval)duration;
- (void)performAnimations:(void (^)(void))animations completion:(void (^)(void))completion duration:(NSTimeInterval)duration;
- (NSTimeInterval)animationDuration;

@end
