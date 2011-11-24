//
//  ADLList+CollectionAdditions.m
//  julep
//
//  Created by Akiva Leffert on 11/7/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ADLList+CollectionAdditions.h"

@implementation ADLList (CollectionAdditions)

- (void)mutateItemsSet:(void (^)(NSMutableOrderedSet* set))mutator {
    NSMutableOrderedSet* set = [self mutableOrderedSetValueForKey:@"items"];
    mutator(set);
}

@end
