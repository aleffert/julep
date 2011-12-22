//
//  ADLListViewController.h
//  julep
//
//  Created by Akiva Leffert on 9/19/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ADLModelAccess.h"
#import "ADLItemView.h"
#import "ADLTableView.h"

@protocol ADLListViewControllerDelegate;

@interface ADLListViewController : NSViewController <ADLListChangedListener, NSTableViewDataSource, ADLTableViewDelegate, ADLItemViewDelegate>

@property (retain, nonatomic) ADLModelAccess* modelAccess;
@property (retain, nonatomic) ADLListID* listID;
@property (assign, nonatomic) id <ADLListViewControllerDelegate> delegate;

@property (copy, nonatomic) NSArray* items;

- (void)didActivate;

@end


@protocol ADLListViewControllerDelegate <NSObject>

- (void)listViewControllerWillDealloc:(ADLListViewController*)controller;

@end