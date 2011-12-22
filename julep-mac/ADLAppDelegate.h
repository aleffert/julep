//
//  ADLAppDelegate.h
//  julep-mac
//
//  Created by Akiva Leffert on 8/22/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ADLAppServer.h"
#import "ADLModelAccess.h"
#import "ADLPreferencesController.h"

@interface ADLAppDelegate : NSObject <NSApplicationDelegate, ADLPreferencesControllerDelegate, ADLModelChangedListener, ADLAppServerDelegate>

@end
