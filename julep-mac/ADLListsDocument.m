//
//  ADLListsDocument.m
//  julep
//
//  Created by Akiva Leffert on 9/26/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "ADLListsDocument.h"

#import "ADLListsWindowController.h"
#import "ADLModelAccess.h"

@interface ADLListsDocument ()

@property (retain, nonatomic) ADLModelAccess* modelAccess;

@end

@implementation ADLListsDocument

@synthesize modelAccess = mModelAccess;


- (void)dealloc {
    self.modelAccess = nil;
    [super dealloc];
}

- (void)makeWindowControllers {
    ADLListsWindowController* windowController = [[ADLListsWindowController alloc] initWithWindowNibName:@"ADLListsWindowController"];
    
    [self addWindowController:windowController];
    
    [windowController release];
}

- (BOOL)configurePersistentStoreCoordinatorForURL:(NSURL *)storeURL ofType:(NSString *)fileType modelConfiguration:(NSString *)configuration storeOptions:(NSDictionary *)storeOptions error:(NSError **)error{
    BOOL success = [super configurePersistentStoreCoordinatorForURL:storeURL ofType:fileType modelConfiguration:configuration storeOptions:storeOptions error:error];
    
    if(success) {
        self.modelAccess = [[[ADLModelAccess alloc] initWithManagedObjectContext:self.managedObjectContext] autorelease];
        self.modelAccess.delegate = self;
    }
    
    return success;
}
- (BOOL)isDocumentEdited {
    return NO;
}

- (void)modelDidMutate:(ADLModelAccess *)modelAccess {
    NSError* error = nil;
    [self.managedObjectContext save:&error];
    NSAssert(error == nil, @"Error saving model changes: %@", error);
}

- (NSApplicationTerminateReply)shouldApplicationTerminate {
    NSManagedObjectContext* managedObjectContext = self.managedObjectContext;
    if (![managedObjectContext commitEditing]) {
        NSLog(@"%@:%@ unable to commit editing to terminate", [self class], NSStringFromSelector(_cmd));
        return NSTerminateCancel;
    }
    
    if (![managedObjectContext hasChanges]) {
        return NSTerminateNow;
    }
    
    NSError *error = nil;
    if (![managedObjectContext save:&error]) {
        
        // Customize this code block to include application-specific recovery steps.              
        BOOL result = [NSApp presentError:error];
        if (result) {
            return NSTerminateCancel;
        }
        
        NSString *question = NSLocalizedString(@"Could not save changes while quitting. Quit anyway?", @"Quit without saves error question message");
        NSString *info = NSLocalizedString(@"Quitting now will lose any changes you have made since the last successful save", @"Quit without saves error question info");
        NSString *quitButton = NSLocalizedString(@"Quit anyway", @"Quit anyway button title");
        NSString *cancelButton = NSLocalizedString(@"Cancel", @"Cancel button title");
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:question];
        [alert setInformativeText:info];
        [alert addButtonWithTitle:quitButton];
        [alert addButtonWithTitle:cancelButton];
        
        NSInteger answer = [alert runModal];
        [alert release];
        
        if (answer == NSAlertAlternateReturn) {
            return NSTerminateCancel;
        }
    }
    
    return NSTerminateNow;
}

@end
