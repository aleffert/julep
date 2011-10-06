//
//  ADLListCollection.h
//  julep
//
//  Created by Akiva Leffert on 9/30/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class ADLList;

@interface ADLListCollection : NSManagedObject {
@private
}
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSOrderedSet *lists;
@end

@interface ADLListCollection (CoreDataGeneratedAccessors)

- (void)insertObject:(ADLList *)value inListsAtIndex:(NSUInteger)idx;
- (void)removeObjectFromListsAtIndex:(NSUInteger)idx;
- (void)insertLists:(NSArray *)value atIndexes:(NSIndexSet *)indexes;
- (void)removeListsAtIndexes:(NSIndexSet *)indexes;
- (void)replaceObjectInListsAtIndex:(NSUInteger)idx withObject:(ADLList *)value;
- (void)replaceListsAtIndexes:(NSIndexSet *)indexes withLists:(NSArray *)values;
- (void)addListsObject:(ADLList *)value;
- (void)removeListsObject:(ADLList *)value;
- (void)addLists:(NSOrderedSet *)values;
- (void)removeLists:(NSOrderedSet *)values;
@end
