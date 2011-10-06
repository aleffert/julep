//
//  ADLTabView.h
//  julep
//
//  Created by Akiva Leffert on 8/22/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ADLView.h"

@protocol ADLTabViewDelegate;

@protocol ADLTabView <ADLView>

@property (retain, nonatomic) NSString* title;
@property (readonly, assign, nonatomic) id <ADLTabViewDelegate> delegate;
@property (assign, nonatomic) BOOL selected;

@end



@protocol ADLTabViewDelegate <NSObject>

- (void)shouldChangeTitleOfTab:(id <ADLTabView>)tab to:(NSString*)newTitle;
- (void)shouldSelectTab:(id <ADLTabView>)tab;

- (void)beginDraggingTab:(id <ADLTabView>)tab;
- (void)draggedTab:(id <ADLTabView>)tab toParentLocation:(CGFloat)xLocation withDelta:(CGFloat)delta;
- (void)endDraggingTab:(id <ADLTabView>)tab;
- (void)cancelDraggingTab:(id <ADLTabView>)tab;
                                
@end