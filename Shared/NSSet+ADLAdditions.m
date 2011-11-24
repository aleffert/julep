//
//  NSSet+ADLAdditions.m
//  julep
//
//  Created by Akiva Leffert on 11/8/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "NSSet+ADLAdditions.h"


static CFStringRef ADLCopyDescriptionFunction(const void* object) {
    return (CFStringRef)[[((id)object) description] retain];
}

static Boolean ADLIsEqualFunction(const void* object, const void* object2) {
    return [(id)object isEqual:(id)object2];
}

static CFHashCode ADLHashFunction(const void* object) {
    return [(id)object hash];
}

@implementation NSMutableSet (ADLAdditions)

+ (NSMutableSet*)nonretainingMutableSet {
    CFSetCallBacks callbacks = {0, NULL, NULL, ADLCopyDescriptionFunction, ADLIsEqualFunction, ADLHashFunction};
    CFSetRef set = CFSetCreateMutable(NULL, 0, &callbacks);
    
    NSMutableSet* result = (NSMutableSet*)set;
    return [result autorelease];
}

@end
