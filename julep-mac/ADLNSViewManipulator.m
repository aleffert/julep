//
//  ADLNSViewManipulator.m
//  julep
//
//  Created by Akiva Leffert on 8/22/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ADLNSViewManipulator.h"

#import <objc/runtime.h>

#import "ADLFloatUtilities.h"
#import "ADLView.h"


static NSString* kADLNSViewManipulatorFinalValuesKey = @"kADLNSViewManipulatorFinalValuesKey";

@interface ADLNSViewManipulator ()

@property (readonly, nonatomic, getter = isAnimating) BOOL animating;
- (void)incrementAnimationDepth;
- (void)decrementAnimationDepth;

@end

@implementation ADLNSViewManipulator

- (void)addSubview:(id <ADLView>)subview toView:(id <ADLView>)parentView {
    NSView* view = (NSView*)parentView;
    NSView* child = (NSView*)subview;
    [view addSubview:child];
}

- (void)orderViewFront:(id <ADLView>)view {
    NSView* nsView = (NSView*)view;
    NSView* superview = nsView.superview;
    [superview addSubview:nsView positioned:NSWindowAbove relativeTo:nil];
}

- (NSView*)coerceViewIncludingAnimation:(id <ADLView>)view {
    NSView* nsView = (NSView*)view;
    if(self.animating) {
        return [nsView animator];
    }
    else {
        return nsView;
    }
}

- (void)setFinalValue:(NSValue*)value forKey:(NSString*)key ofView:(id <ADLView>)view {
    NSMutableDictionary* finalValues = objc_getAssociatedObject(view, kADLNSViewManipulatorFinalValuesKey);
    if(finalValues == nil) {
        finalValues = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(view, kADLNSViewManipulatorFinalValuesKey, finalValues, OBJC_ASSOCIATION_RETAIN);
    }
    [finalValues setObject:value forKey:key];
}

- (NSValue*)finalValueForKey:(NSString*)key ofView:(id <ADLView>)view {
    NSMutableDictionary* finalValues = objc_getAssociatedObject(view, kADLNSViewManipulatorFinalValuesKey);
    return [finalValues objectForKey:key];
}

- (void)clearFinalValueForKey:(NSString*)key ofView:(id <ADLView>)view {
    NSMutableDictionary* finalValues = objc_getAssociatedObject(view, kADLNSViewManipulatorFinalValuesKey);
    [finalValues removeObjectForKey:key];
    if(finalValues.count == 0 && finalValues != nil) {
        objc_setAssociatedObject(view, kADLNSViewManipulatorFinalValuesKey, nil, OBJC_ASSOCIATION_RETAIN);
    }
}

- (CGRect)frameOfView:(id <ADLView>)view {
    NSView* nsView = (NSView*)view;
    NSValue* savedFrame = [self finalValueForKey:@"frame" ofView:view];
    if(savedFrame == nil) {
        return NSRectToCGRect(nsView.frame);
    }
    else {
        return NSRectToCGRect([savedFrame rectValue]);
    }
}
- (void)setFrame:(CGRect)frame ofView:(id <ADLView>)view {
    NSView* nsView = [self coerceViewIncludingAnimation:view];
    nsView.frame = NSRectFromCGRect(frame);
    if(self.animating) {
        [self setFinalValue:[NSValue valueWithRect:NSRectFromCGRect(frame)] forKey:@"frame" ofView:view];
    }
    else {
        [self clearFinalValueForKey:@"frame" ofView:view];
    }
}

- (CGSize)contentSizeOfScrollView:(id <ADLScrollView>)scrollView {
    NSScrollView* nsScrollView = (NSScrollView*)scrollView;
    NSView* documentView = nsScrollView.documentView;
    return NSSizeToCGSize(documentView.frame.size);
}

- (void)setContentSize:(CGSize)size ofScrollView:(id <ADLScrollView>)scrollView {
    NSScrollView* nsScrollView = (NSScrollView*)scrollView;
    CGRect documentFrame = [self frameOfView:nsScrollView.documentView];
    CGSize documentSize = documentFrame.size;
    if(!ADLFloatsAlmostEqual(documentSize.width, size.width) || !ADLFloatsAlmostEqual(documentSize.height, size.height)) {
        documentFrame.size.width = size.width;
        documentFrame.size.height = size.height;
        [nsScrollView.documentView setFrame:NSRectFromCGRect(documentFrame)];
    }
}

- (CGFloat)alphaOfView:(NSView*)view {
    return view.alphaValue;
}

- (void)setAlpha:(CGFloat)alpha ofView:(NSView*)view {
    view.alphaValue = alpha;
}


- (BOOL)isAnimating {
    return mAnimationCount > 0;
}

- (void)incrementAnimationDepth {
    OSAtomicIncrement32Barrier(&mAnimationCount);
}

- (void)decrementAnimationDepth {
    OSAtomicDecrement32Barrier(&mAnimationCount);
}

- (void)performAnimations:(void (^)(void))animations duration:(NSTimeInterval)duration {
    [self performAnimations:animations completion:^(void){ } duration:duration];
}

- (void)performAnimations:(void (^)(void))animations completion:(void (^)(void))completion duration:(NSTimeInterval)duration {
    [self incrementAnimationDepth];
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext* context) {
        context.duration = duration;
        animations();
    } completionHandler:completion];
    [self decrementAnimationDepth];
}

- (NSTimeInterval)animationDuration {
    return [[NSAnimationContext currentContext] duration];
}

@end
