//
//  ADLTableView.h
//  julep
//
//  Created by Akiva Leffert on 12/11/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <AppKit/AppKit.h>

@protocol ADLTableViewDelegate;

@interface ADLTableView : NSTableView

@end

@interface ADLTableView (ADLCast)

- (void)setDelegate:(id<ADLTableViewDelegate>)delegate;
- (id <ADLTableViewDelegate>)delegate;

@end


@protocol ADLTableViewDelegate <NSTableViewDelegate>

- (void)tableViewShouldToggleSelection:(ADLTableView*)tableView;
- (void)tableViewShouldEditSelection:(ADLTableView*)tableView;
- (void)tableViewShouldClearSelection:(ADLTableView*)tableView;

@end