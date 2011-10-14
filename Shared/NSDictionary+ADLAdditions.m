//
//  NSDictionary+ADLAdditions.m
//  julep
//
//  Created by Akiva Leffert on 10/10/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "NSDictionary+ADLAdditions.h"

static CFStringRef ADLCopyDescriptionFunction(const void* object) {
    return (CFStringRef)[[((id)object) description] retain];
}

static Boolean ADLIsEqualFunction(const void* object, const void* object2) {
    return [(id)object isEqual:(id)object2];
}

static CFHashCode ADLHashFunction(const void* object) {
    return [(id)object hash];
}

@implementation NSDictionary (ADLAdditions)

+ (NSMutableDictionary*)noCopyingMutableDictionary {
    CFDictionaryKeyCallBacks keyCallbacks = {0, NULL, NULL, ADLCopyDescriptionFunction, ADLIsEqualFunction, ADLHashFunction};
    CFDictionaryRef dictionary = CFDictionaryCreateMutable(NULL, 1, &keyCallbacks, &kCFTypeDictionaryValueCallBacks);
    return [((NSMutableDictionary*)dictionary) autorelease];
}

@end
