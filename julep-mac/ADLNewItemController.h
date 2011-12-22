//
//  ADLNewItemController.h
//  julep
//
//  Created by Akiva Leffert on 12/21/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol ADLNewItemControllerDelegate;

@interface ADLNewItemController : NSWindowController <NSTableViewDelegate, NSTableViewDataSource, NSTextFieldDelegate, NSWindowDelegate>

@property (assign, nonatomic) id <ADLNewItemControllerDelegate> delegate;
@property (copy, nonatomic) NSArray* listNames;
@property (copy, nonatomic) NSArray* listIDs;

@end

@protocol ADLNewItemControllerDelegate <NSObject>

- (void)addItemWithTitle:(NSString*)name toList:(NSURL*)url;

@end