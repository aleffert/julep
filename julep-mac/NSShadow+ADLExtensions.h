//
//  NSShadow+ADLExtensions.h
//  julep
//
//  Created by Akiva Leffert on 9/16/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <AppKit/AppKit.h>

@interface NSShadow (ADLExtensions)

// Default properties. Same as CALayer defaults modulo flipped coordinates, but with opacity = 1., black, blur 3, (0, 3) offset
+ (NSShadow*)standardShadow;

@end
