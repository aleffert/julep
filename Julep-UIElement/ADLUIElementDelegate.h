//
//  ADLUIElementDelegate.h
//  Julep-UIElement
//
//  Created by Akiva Leffert on 12/21/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ADLNewItemController.h"
#import "ADLUIElementServer.h"

@interface ADLUIElementDelegate : NSObject <NSApplicationDelegate, ADLUIElementServerDelegate, ADLNewItemControllerDelegate>

@end
