//
//  ADLFloatUtilities.m
//  julep
//
//  Created by Akiva Leffert on 8/26/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ADLFloatUtilities.h"

BOOL ADLFloatsAlmostEqual(CGFloat left, CGFloat right) {
    return fabs(left - right) < .0001;
}