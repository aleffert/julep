//
//  ADLUIElementServer.m
//  julep
//
//  Created by Akiva Leffert on 12/21/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ADLUIElementServer.h"

NSString* kADLUIServerName = @"com.ognid.julep-ui-server";

@interface ADLUIElementServer ()

@property (retain, nonatomic) NSConnection* connection;

@end

@implementation ADLUIElementServer

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
    if([self.connection registerName:kADLUIServerName] == NO) {
        NSLog(@"failed to start ui element server");
    };
}

- (void)showQuickCreateWithListIDs:(NSArray*)listIDs named:(NSArray*)names {
    [self.delegate showQuickCreateWithListIDs:listIDs named:names];
}

- (void)showQuickToggle {
    [self.delegate showQuickToggle];
}

- (void)updateQuickToggleItemsTo:(NSArray*)items {
    [self.delegate updateQuickToggleItemsTo:items];
}

@end
