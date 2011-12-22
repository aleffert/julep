//
//  ADLNSTabViewController.h
//  julep
//
//  Created by Akiva Leffert on 8/22/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ADLTabController.h"

#import "ADLNSScrollView.h"

@interface ADLNSTabViewController : NSViewController <ADLTabControllerDelegate>

- (id)initWithDataSource:(id <ADLTabControllerDataSource>)dataSource;

@property (retain, nonatomic) id <ADLViewManipulator> viewManipulator;

@property (readonly, retain, nonatomic) ADLTabController* agnostic;

@end
