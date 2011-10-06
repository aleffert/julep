//
//  NSShadow+ADLExtensions.m
//  julep
//
//  Created by Akiva Leffert on 9/16/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "NSShadow+ADLExtensions.h"

@implementation NSShadow (ADLExtensions)

+ (NSShadow*)standardShadow {
    NSShadow* shadow = [[NSShadow alloc] init];
    shadow.shadowColor = [NSColor blackColor];
    shadow.shadowBlurRadius = 3.;
    shadow.shadowOffset = NSMakeSize(0, 3);
    return [shadow autorelease];
}

@end
