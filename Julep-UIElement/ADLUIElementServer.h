//
//  ADLUIElementServer.h
//  julep
//
//  Created by Akiva Leffert on 12/21/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol ADLUIElementServerDelegate;

@protocol ADLUIElementServer <NSObject>

- (void)showQuickCreateWithListIDs:(NSArray*)listIDs named:(NSArray*)names;
- (void)showQuickToggle;
- (void)updateQuickToggleItemsTo:(NSArray*)items;

@end

@interface ADLUIElementServer : NSObject <ADLUIElementServer>

@property (assign, nonatomic) id <ADLUIElementServerDelegate> delegate;

- (void)start;

@end


@protocol ADLUIElementServerDelegate <NSObject>

- (void)showQuickCreateWithListIDs:(NSArray*)listIDs named:(NSArray*)names;
- (void)showQuickToggle;
- (void)updateQuickToggleItemsTo:(NSArray*)items;

@end

extern NSString* kADLUIServerName;