//
//  ADLListsDocument.h
//  julep
//
//  Created by Akiva Leffert on 9/26/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ADLModelAccess.h"

@interface ADLListsDocument : NSPersistentDocument <ADLModelAccessDelegate> {
    ADLModelAccess* mModelAccess;
}

- (NSApplicationTerminateReply)shouldApplicationTerminate;

@property (readonly, retain, nonatomic) ADLModelAccess* modelAccess;

@end
