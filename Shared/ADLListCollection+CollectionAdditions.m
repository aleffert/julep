//
//  ADLListCollection+CollectionAdditions.m
//  julep
//
//  Created by Akiva Leffert on 9/28/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "ADLListCollection.h"

@implementation ADLListCollection (CollectionAdditions)

- (void)mutateListsSet:(void (^)(NSMutableOrderedSet* set))mutator {
    NSMutableOrderedSet* set = [self mutableOrderedSetValueForKey:@"lists"];
    mutator(set);
}

@end
