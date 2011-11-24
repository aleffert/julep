//
//  ADLNSViewManipulator.h
//  julep
//
//  Created by Akiva Leffert on 8/22/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ADLViewManipulator.h"

@interface ADLNSViewManipulator : NSObject <ADLViewManipulator>
{
    volatile int32_t mAnimationCount;
}

@end
