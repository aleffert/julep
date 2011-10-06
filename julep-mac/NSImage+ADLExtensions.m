//
//  NSImage+ADLExtensions.m
//  julep
//
//  Created by Akiva Leffert on 8/24/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "NSImage+ADLExtensions.h"

@implementation NSImage (ADLExtensions)

- (CGImageRef)CGImage {
    return [self CGImageForProposedRect:NULL context:nil hints:nil];
}

@end
