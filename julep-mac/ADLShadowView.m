//
//  ADLShadowView.m
//  julep
//
//  Created by Akiva Leffert on 12/12/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ADLShadowView.h"

@implementation ADLShadowView

@synthesize insets = mInsets;
@synthesize shadow = mShadow;

- (void)dealloc {
    self.shadow = nil;
    [super dealloc];
}

- (void)drawRect:(NSRect)dirtyRect
{
    [self.shadow set];
    [[NSColor redColor] set];
    NSRect fillRect = NSMakeRect(self.bounds.origin.x + self.insets.left, self.bounds.origin.y + self.insets.bottom, self.bounds.size.width - self.insets.left - self.insets.right, self.bounds.size.height - self.insets.top - self.insets.bottom);
    NSRectFill(fillRect);
}

@end
