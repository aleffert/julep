//
//  ADLAppDelegate.m
//  julep-mac
//
//  Created by Akiva Leffert on 8/22/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ADLAppDelegate.h"

#import "ADLColor.h"
#import "ADLListsWindowController.h"
#import "ADLListsDocument.h"
#import "ADLModelAccess.h"

@interface ADLAppDelegate ()

@property (retain, nonatomic) ADLListsWindowController* listsWindowController;

- (void)openMainDocument;
- (NSString*)mainDocumentName;
- (NSString*)applicationName;
- (NSURL*)applicationSupportSubdirectoryURL;

@property (retain, nonatomic) ADLListsDocument* mainDocument;

@end

static NSString* kADLApplicationName = @"Julep";
static NSString* kADLMainDocumentName = @"database.julep";
static NSString* kADLJulepDocumentType = @"julep";

@implementation ADLAppDelegate

@synthesize listsWindowController = mListsWindowController;
@synthesize mainDocument = mMainDocument;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [self openMainDocument];
}

- (NSString*)mainDocumentName {
    return kADLMainDocumentName;
}

- (NSString*)applicationName {
    return kADLApplicationName;
}

- (NSURL*)applicationSupportSubdirectoryURL {
    NSArray* urls = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask];
    NSAssert(urls.count > 0, @"Unable to find application support directory");
    NSURL* appSupportURL = [urls objectAtIndex:0];
    return [appSupportURL URLByAppendingPathComponent:self.applicationName isDirectory:YES];
}

- (NSURL*)mainDocumentURL {
    return [self.applicationSupportSubdirectoryURL URLByAppendingPathComponent:self.mainDocumentName];
}

- (void)openMainDocument {
    NSError* error = nil;
    ADLListsDocument* document = nil;
    if([self.mainDocumentURL checkResourceIsReachableAndReturnError:&error]) {
        document = [[ADLListsDocument alloc] initWithContentsOfURL: self.mainDocumentURL ofType:kADLJulepDocumentType error:&error];
    }
    else {
        error = nil;
        [[NSFileManager defaultManager] createDirectoryAtURL:self.applicationSupportSubdirectoryURL withIntermediateDirectories:YES attributes:nil error:&error];
        NSAssert(error == nil, @"Error creating application support subdirectory: %@", error);
        document = [[ADLListsDocument alloc] init];
        [document saveToURL:self.mainDocumentURL ofType:kADLJulepDocumentType forSaveOperation:NSSaveOperation error:&error];
        [document.modelAccess populateDefaults];
    }
    
    NSAssert(document != nil, @"Unable to open main document");
    NSAssert(error == nil, @"Error opening document: %@", error);
    
    self.mainDocument = document;
    
    [[NSDocumentController sharedDocumentController] addDocument:self.mainDocument];
    [self.mainDocument makeWindowControllers];
    
    [document release];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    return [self.mainDocument shouldApplicationTerminate];
}

- (void)applicationWillBecomeActive:(NSNotification *)notification {
    [self.mainDocument showWindows];
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender {
    return NO;
}

@end
