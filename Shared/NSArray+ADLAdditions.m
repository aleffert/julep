//
//  NSArray+ADLAdditions.m
//  julep
//
//  Created by Akiva Leffert on 9/28/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "NSArray+ADLAdditions.h"

@implementation NSArray (ADLAdditions)

- (NSArray*)arrayByMappingObjects:(id (^)(id object))mapper {
    NSMutableArray* result = [NSMutableArray array];
    for(id object in self) {
        [result addObject:mapper(object)];
    }
    
    return result;
}

@end

@implementation NSMutableArray (ADLAdditions)

+ (NSArray*)nonretainingMutableArray {
    CFArrayCallBacks callbacks = {0, NULL, NULL, NULL, NULL};
    CFArrayRef resultArray = CFArrayCreateMutable(NULL, 1, &callbacks);
    NSMutableArray* result = (NSMutableArray*)resultArray;
    
    return [result autorelease];
}


@end
