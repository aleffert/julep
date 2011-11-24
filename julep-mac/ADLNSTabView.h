//
//  ADLNSTabView.h
//  julep
//
//  Created by Akiva Leffert on 8/22/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ADLTabView.h"

@protocol ADLTabViewDelegate;

@interface ADLNSTabView : NSView <ADLTabView, NSTextFieldDelegate> {
    CALayer* mBackgroundLayer;
    NSTextField* mTitleView;
    NSPoint mCurrentDragLocation;
    id <ADLTabViewDelegate> mDelegate;
    BOOL mDragging;
    NSTimer* mDragTimer;
    NSString* mTitle;
    BOOL mSelected;
}

@property (assign, nonatomic) id <ADLTabViewDelegate> delegate;

@end