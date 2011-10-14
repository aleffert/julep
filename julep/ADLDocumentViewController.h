//
//  ADLDocumentViewController.h
//  julep
//
//  Created by Akiva Leffert on 10/7/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "ADLPageScrollViewController.h"

#import "ADLModelAccess.h"

@interface ADLDocumentViewController : UIViewController <ADLPageScrollViewControllerDelegate, ADLCollectionChangedListener>

@property (retain, nonatomic) ADLModelAccess* modelAccess;

@end
