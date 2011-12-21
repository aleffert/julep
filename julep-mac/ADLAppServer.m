//
//  ADLAppServer.m
//  julep
//
//  Created by Akiva Leffert on 12/21/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ADLAppServer.h"

NSString* kADLAppServerName = @"com.ognid.julep";

@interface ADLAppServer ()

@property (retain, nonatomic) NSConnection* connection;

@end

@implementation ADLAppServer

@synthesize connection = mConnection;
@synthesize delegate = mDelegate;

- (void)dealloc {
    [self.connection invalidate];
    self.connection = nil;
    [super dealloc];
}

- (void)start {
    self.connection = [[[NSConnection alloc] init] autorelease];
    self.connection.rootObject = self;
    if([self.connection registerName:kADLAppServerName] == NO) {
        NSLog(@"failed to start app server");
    };
}

- (void)addItemWithTitle:(NSString *)title toList:(NSURL *)list {
    [self.delegate addItemWithTitle:title toList:list];
}

@end
