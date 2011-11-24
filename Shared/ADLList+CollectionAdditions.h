//
//  ADLList+CollectionAdditions.h
//  julep
//
//  Created by Akiva Leffert on 11/7/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ADLList.h"

@interface ADLList (CollectionAdditions)

- (void)mutateItemsSet:(void (^)(NSMutableOrderedSet* set))mutator;

@end
