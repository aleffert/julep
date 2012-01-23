//
//  ADLItemView.h
//  julep
//
//  Created by Akiva Leffert on 11/9/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <AppKit/AppKit.h>

#import "ADLModelAccess.h"

@protocol ADLItemViewDelegate;

@interface ADLItemView : NSView <NSTextFieldDelegate>

@property (retain, nonatomic) ADLItemID* item;
@property (copy, nonatomic) NSString* title;
@property (assign, nonatomic) BOOL checked;

@property (assign, nonatomic) id <ADLItemViewDelegate> delegate;

- (void)beginEditing;

@end


@protocol ADLItemViewDelegate <NSObject>

- (void)itemViewDidBeginEditing:(ADLItemView*)item;
- (void)itemViewDidEndEditing:(ADLItemView*)item;

- (void)itemView:(ADLItemView*)itemView changedTitle:(NSString*)item;
- (void)itemView:(ADLItemView*)itemView changedCompletionStatus:(BOOL)status;
- (void)itemViewCancelledEditing:(ADLItemView*)itemView;

@end