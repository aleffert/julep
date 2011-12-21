//
//  ADLList.h
//  julep
//
//  Created by Akiva Leffert on 10/14/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class ADLItem, ADLListCollection;

@interface ADLList : NSManagedObject

@property (nonatomic, retain) NSString * uid;
@property (nonatomic, retain) NSOrderedSet *items;
@property (nonatomic, retain) ADLListCollection *list;
@property (nonatomic, assign) BOOL showsCountInBadge;
@end

@interface ADLList (CoreDataGeneratedAccessors)

- (void)insertObject:(ADLItem *)value inItemsAtIndex:(NSUInteger)idx;
- (void)removeObjectFromItemsAtIndex:(NSUInteger)idx;
- (void)insertItems:(NSArray *)value atIndexes:(NSIndexSet *)indexes;
- (void)removeItemsAtIndexes:(NSIndexSet *)indexes;
- (void)replaceObjectInItemsAtIndex:(NSUInteger)idx withObject:(ADLItem *)value;
- (void)replaceItemsAtIndexes:(NSIndexSet *)indexes withItems:(NSArray *)values;
- (void)addItemsObject:(ADLItem *)value;
- (void)removeItemsObject:(ADLItem *)value;
- (void)addItems:(NSOrderedSet *)values;
- (void)removeItems:(NSOrderedSet *)values;
@end
