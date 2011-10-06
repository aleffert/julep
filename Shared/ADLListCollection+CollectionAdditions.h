//
//  ADLListCollection+CollectionAdditions.h
//  julep
//
//  Created by Akiva Leffert on 9/28/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "ADLListCollection.h"

@interface ADLListCollection (CollectionAdditions)

- (void)mutateListsSet:(void (^)(NSMutableOrderedSet* set))mutator;

@end
