//
//  ADLListsDocument.h
//  julep
//
//  Created by Akiva Leffert on 10/7/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "ADLModelAccess.h"

@interface ADLListsDocument : UIManagedDocument <ADLModelAccessDelegate>

@property (readonly, retain, nonatomic) ADLModelAccess* modelAccess;

@end
