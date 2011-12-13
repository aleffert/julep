//
//  ADLColorView.m
//  julep
//
//  Created by Akiva Leffert on 9/19/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ADLColorView.h"

@implementation ADLColorView

@synthesize backgroundColor = mBackgroundColor;

- (void)dealloc {
    self.backgroundColor = nil;
    [super dealloc];
}

- (void)drawRect:(NSRect)dirtyRect {
    [self.backgroundColor setFill];
    NSRectFill(dirtyRect);
    
}

@end
