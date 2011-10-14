//
//  ADLUITabViewController.h
//  julep
//
//  Created by Akiva Leffert on 10/8/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "ADLTabController.h"

@interface ADLUITabViewController : UIViewController <ADLTabControllerDelegate>

- (id)initWithDataSource:(id <ADLTabControllerDataSource>)dataSource;

@property (retain, nonatomic) id <ADLViewManipulator> viewManipulator;

@property (readonly, retain, nonatomic) ADLTabController* agnostic;

@end
