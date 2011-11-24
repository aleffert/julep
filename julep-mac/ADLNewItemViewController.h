//
//  ADLNewItemViewController.h
//  julep
//
//  Created by Akiva Leffert on 11/20/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ADLModelAccess.h"

enum {
    ADLNewItemCreateReturnCode = 1000,
    ADLNewItemCancelReturnCode
};

@interface ADLNewItemViewController : NSViewController

// These aren't valid unless the view is loaded
@property (retain, nonatomic) ADLListID* selectedList;
@property (retain, nonatomic) NSString* itemTitle;

- (void)addListID:(ADLListID*)list withName:(NSString*)name;

- (void)willPresentAsSheet;

- (IBAction)createItem:(id)sender;
- (IBAction)cancelCreation:(id)sender;

@end
