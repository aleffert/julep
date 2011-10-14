//
//  ADLListViewController.m
//  julep
//
//  Created by Akiva Leffert on 10/10/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ADLListViewController.h"

@implementation ADLListViewController

@synthesize listID = mListID;

- (id)init {
    return [self initWithNibName:nil bundle:nil];
}

- (void)dealloc {
    self.listID = nil;
    [super dealloc];
}

@end
