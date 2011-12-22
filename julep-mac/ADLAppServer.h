//
//  ADLAppServer.h
//  julep
//
//  Created by Akiva Leffert on 12/21/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ADLModelAccess.h"

@protocol ADLAppServerDelegate;

@protocol ADLAppServer <NSObject>

- (void)addItemWithTitle:(NSString*)title toList:(NSURL*)list;
- (NSArray*)itemsWithSearchString:(NSString*)query;
- (void)toggleItemAtURL:(NSURL*)url;

@end


@interface ADLAppServer : NSObject <ADLAppServer>

@property (assign, nonatomic) id <ADLAppServerDelegate> delegate;

- (void)start;

@end


@protocol ADLAppServerDelegate <NSObject>

- (void)addItemWithTitle:(NSString*)title toList:(NSURL *)list;
- (NSArray*)itemsWithSearchString:(NSString*)query;
- (void)toggleItemAtURL:(NSURL*)url;

@end

extern NSString* kADLAppServerName;