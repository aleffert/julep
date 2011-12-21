//
//  ADLUIElementDelegate.m
//  Julep-UIElement
//
//  Created by Akiva Leffert on 12/21/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ADLUIElementDelegate.h"

#import "ADLAppServer.h"
#import "ADLNewItemController.h"

@interface ADLUIElementDelegate ()

@property (retain, nonatomic) ADLUIElementServer* server;
@property (retain, nonatomic) ADLNewItemController* quickCreateController;

@end

@implementation ADLUIElementDelegate

@synthesize quickCreateController = mQuickCreateController;
@synthesize server = mServer;

- (void)dealloc
{
    self.quickCreateController = nil;
    self.server = nil;
    [super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [[NSWorkspace sharedWorkspace] addObserver:self forKeyPath:@"runningApplications" options:NSKeyValueObservingOptionNew context:NULL];
    self.server = [[[ADLUIElementServer alloc] init] autorelease];
    self.server.delegate = self;
    [self.server start];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    NSAssert([keyPath isEqual:@"runningApplications"], @"unexpected key path");
    NSArray* items = [NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.ognid.julep"];
    if(items.count == 0) {
        [[NSApplication sharedApplication] terminate:self];
    }
}

- (void)showQuickCreateWithListIDs:(NSArray*)listIDs named:(NSArray*)names {
    if(self.quickCreateController == nil) {
        self.quickCreateController = [[[ADLNewItemController alloc] init] autorelease];
        self.quickCreateController.delegate = self;
    }
    self.quickCreateController.listNames = names;
    self.quickCreateController.listIDs = listIDs;
    [self.quickCreateController showWindow:self];
}

- (void)addItemWithTitle:(NSString *)name toList:(NSURL *)listID {
    id <ADLAppServer> appServer = (id <ADLAppServer>)[NSConnection rootProxyForConnectionWithRegisteredName:kADLAppServerName host:nil];
    [appServer addItemWithTitle:name toList:listID];
}

- (void)applicationWillResignActive:(NSNotification *)notification {
    [self.quickCreateController.window orderOut:self];
}

@end
