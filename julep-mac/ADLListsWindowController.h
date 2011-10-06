//
//  ADLListsWindowController.h
//  julep
//
//  Created by Akiva Leffert on 9/17/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class ADLListsDocument;

@interface ADLListsWindowController : NSWindowController <NSWindowDelegate>

@end

@interface ADLListsWindowController (ADLCast)

- (ADLListsDocument*)document;

@end
