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

@interface ADLNSTabView : NSView <ADLTabView, NSTextFieldDelegate>

@property (assign, nonatomic) id <ADLTabViewDelegate> delegate;

@end