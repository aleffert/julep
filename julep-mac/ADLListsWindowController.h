//
//  ADLListsWindowController.h
//  julep
//
//  Created by Akiva Leffert on 9/17/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class ADLListsDocument;
@class ADLDocumentViewController;

@interface ADLListsWindowController : NSWindowController <NSWindowDelegate> {
    ADLDocumentViewController* mDocumentViewController;
}

@end

@interface ADLListsWindowController (ADLCast)

- (ADLListsDocument*)document;

@end
