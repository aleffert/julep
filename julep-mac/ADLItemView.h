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

@interface ADLItemView : NSView <NSTextFieldDelegate> {
    ADLItemID* mItem;
    BOOL mChecked;
    NSButton* mCheckbox;
    id <ADLItemViewDelegate> mDelegate;
    NSTextField* mTitleView;
    NSString* mTitle;
}

@property (retain, nonatomic) ADLItemID* item;
@property (copy, nonatomic) NSString* title;
@property (assign, nonatomic) BOOL checked;

@property (assign, nonatomic) id <ADLItemViewDelegate> delegate;

- (void)beginEditing;

@end


@protocol ADLItemViewDelegate <NSObject>

- (void)itemView:(ADLItemView*)itemView changedTitle:(NSString*)item;
- (void)itemView:(ADLItemView*)itemView changedCompletionStatus:(BOOL)status;

@end