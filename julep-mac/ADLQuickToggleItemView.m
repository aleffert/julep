//
//  ADLQuickToggleItemView.m
//  julep
//
//  Created by Akiva Leffert on 12/22/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ADLQuickToggleItemView.h"

@implementation ADLQuickToggleItemView

@synthesize listLabel = mListLabel;
@synthesize titleView = mTitleView;

- (void)dealloc {
    self.listLabel = nil;
    self.titleView = nil;
    [super dealloc];
}


@end
