//
//  ADLListViewController.h
//  julep
//
//  Created by Akiva Leffert on 9/19/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ADLModelAccess.h"

@protocol ADLListViewControllerDelegate;

@interface ADLListViewController : NSViewController <ADLListChangedListener, NSTextViewDelegate>

@property (retain, nonatomic) ADLListID* listID;
@property (assign, nonatomic) id <ADLListViewControllerDelegate> delegate;

@property (retain, nonatomic) NSString* bodyText;

- (void)didActivate;

@end


@protocol ADLListViewControllerDelegate <NSObject>

- (void)listViewControllerWillDealloc:(ADLListViewController*)controller;
- (void)listViewController:(ADLListViewController*)controller textChangedTo:(NSString*)text;

@end