//
//  ADLListsDocument.m
//  julep
//
//  Created by Akiva Leffert on 10/7/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ADLListsDocument.h"

@interface ADLListsDocument ()

@property (retain, nonatomic) ADLModelAccess* modelAccess;

@end

@implementation ADLListsDocument

@synthesize modelAccess;

- (void)dealloc {
    self.modelAccess = nil;
    [super dealloc];
}

- (BOOL)configurePersistentStoreCoordinatorForURL:(NSURL *)storeURL ofType:(NSString *)fileType modelConfiguration:(NSString *)configuration storeOptions:(NSDictionary *)storeOptions error:(NSError **)error{
    BOOL success = [super configurePersistentStoreCoordinatorForURL:storeURL ofType:fileType modelConfiguration:configuration storeOptions:storeOptions error:error];
    
    if(success) {
        self.modelAccess = [[[ADLModelAccess alloc] initWithManagedObjectContext:self.managedObjectContext] autorelease];
        self.modelAccess.delegate = self;
    }
    return success;
}

- (void)modelDidMutate:(ADLModelAccess *)modelAccess {
    // Do nothing. The autosave machinery will deal with it
}

@end
