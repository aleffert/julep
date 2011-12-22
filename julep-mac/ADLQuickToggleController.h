//
//  ADLQuickToggleController.h
//  julep
//
//  Created by Akiva Leffert on 12/22/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol ADLQuickToggleControllerDelegate;

@interface ADLQuickToggleController : NSWindowController <NSWindowDelegate, NSControlTextEditingDelegate, NSTableViewDelegate, NSTableViewDataSource>

@property (assign, nonatomic) id <ADLQuickToggleControllerDelegate> delegate;
@property (copy, nonatomic) NSArray* items;

- (void)updateItemsTo:(NSArray*)items;

@end

@protocol ADLQuickToggleControllerDelegate <NSObject>

- (NSArray*)itemsWithSearchString:(NSString*)query;
- (void)toggleItemWithURL:(NSURL*)url;

@end