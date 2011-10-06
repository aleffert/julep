//
//  ADLListsDocument.h
//  julep
//
//  Created by Akiva Leffert on 9/26/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class ADLModelAccess;

@interface ADLListsDocument : NSPersistentDocument

- (NSApplicationTerminateReply)shouldApplicationTerminate;

@property (readonly, retain, nonatomic) ADLModelAccess* modelAccess;

@end
