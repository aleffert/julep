//
//  ADLModelAccess.m
//  julep
//
//  Created by Akiva Leffert on 9/27/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "ADLModelAccess.h"

#import "ADLList.h"
#import "ADLListCollection.h"
#import "ADLListCollection+CollectionAdditions.h"
#import "NSArray+ADLAdditions.h"

static NSString* kADLSelectedListKey = @"kADLSelectedListKey";

@interface ADLModelAccess ()

@property (retain, nonatomic) NSManagedObjectContext* managedObjectContext;
@property (readonly, nonatomic) ADLListCollection* defaultCollection;
@property (retain, nonatomic) NSManagedObjectID* defaultCollectionID;
@property (retain, nonatomic) NSMutableArray* collectionChangedListeners;
@property (retain, nonatomic) NSMutableArray* listChangedListeners;

- (ADLListID*)setupDefaultSelection;

- (void)addList:(void (^)(ADLList* newList))defaults toCollection:(ADLListCollection*)collection atIndex:(NSUInteger)index;

@end

static NSString* kADLListEntityName = @"List";
static NSString* kADLCollectionEntityName = @"ListCollection";

@implementation ADLModelAccess

@synthesize managedObjectContext = mManagedObjectContext;
@synthesize defaultCollectionID = mDefaultCollectionID;
@synthesize collectionChangedListeners = mCollectionChangedListeners;
@synthesize listChangedListeners = mListChangedListeners;

- (ADLModelAccess*)initWithManagedObjectContext:(NSManagedObjectContext*)context {
    self = [super init];
    if(self) {
        self.managedObjectContext = context;
        self.collectionChangedListeners = [NSMutableArray nonretainingMutableArray];
        self.listChangedListeners = [NSMutableArray nonretainingMutableArray];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(modelChangesSaved:) name:NSManagedObjectContextDidSaveNotification object:self.managedObjectContext];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSManagedObjectContextDidSaveNotification object:self.managedObjectContext];
    self.collectionChangedListeners = nil;
    self.listChangedListeners = nil;
    self.defaultCollectionID = nil;
    self.managedObjectContext = nil;
    [super dealloc];
}

- (NSEntityDescription*)listEntityDescription {
    return [NSEntityDescription entityForName:kADLListEntityName inManagedObjectContext:self.managedObjectContext];
}

- (NSEntityDescription*)collectionEntityDescription {
    return [NSEntityDescription entityForName:kADLCollectionEntityName inManagedObjectContext:self.managedObjectContext];
}

- (void)populateDefaults {
    ADLListCollection* collection = [[ADLListCollection alloc] initWithEntity:self.collectionEntityDescription insertIntoManagedObjectContext:self.managedObjectContext];
    collection.name = @"Default";
    
    [self addList:^(ADLList* list) {
        list.title = @"Now";
        list.countsForBadge = YES;
    } toCollection:collection atIndex:0];
    [collection release];
    [self setupDefaultSelection];
}

- (void)performMutation:(void (^)(void))mutator {
    NSError* error = nil;
    mutator();
    [self.managedObjectContext save:&error];
    NSAssert(error == nil, @"Error saving model changes: %@", error);
}

- (ADLListCollection*)defaultCollection {
    if(self.defaultCollectionID != nil) {
        return (ADLListCollection*)[self.managedObjectContext objectWithID:self.defaultCollectionID];
    }
    else {
        NSFetchRequest* fetchRequest = [[NSFetchRequest alloc] init];
        NSError* error = nil;
        fetchRequest.entity = self.collectionEntityDescription;
        NSArray* collections = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
        NSAssert(collections.count == 1, @"Found wrong number of list collections");
        NSAssert(error == nil, @"Error fetching collection");
        ADLListCollection* collection = [collections objectAtIndex:0];
        self.defaultCollectionID = collection.objectID;
        [fetchRequest release];
        return collection;
    }
}

- (void)addList:(void (^)(ADLList* newList))defaults toCollection:(ADLListCollection*)collection atIndex:(NSUInteger)index {
    [self performMutation:^(void) {
        ADLList* list = [[ADLList alloc] initWithEntity:self.listEntityDescription insertIntoManagedObjectContext:self.managedObjectContext];
        [collection mutateListsSet:^(NSMutableOrderedSet* set) {
            [set insertObject:list atIndex:index];
        }];
        defaults(list);
        [list release];
    }];
}

- (void)deleteListWithID:(ADLListID*)listID {
    NSUInteger index = [self.listIDs indexOfObject:self.selectedListID];
    BOOL updateSelection = [listID isEqual:self.selectedListID];
    [self performMutation:^(void) {
        ADLList* list = (ADLList*)[self.managedObjectContext objectWithID:listID];
        [self.defaultCollection mutateListsSet:^(NSMutableOrderedSet* set) {
            [set removeObject:list];
        }];
        [self.managedObjectContext deleteObject:list];
    }];
    if (updateSelection) {
        if(self.listIDs.count > 0) {
            self.selectedListID = [self.listIDs objectAtIndex:index];
        }
        else {
            self.selectedListID = nil;
        }
    }
}


- (NSArray*)lists {
    return self.defaultCollection.lists.array;
}

- (NSUInteger)listCount {
    return self.lists.count;
}

- (NSArray*)listIDs {
    NSArray* lists = self.lists;
    NSArray* ids = [lists arrayByMappingObjects:^(id object) {
        NSManagedObject* managedObject = object;
        return managedObject.objectID;
    }];
    
    return ids;
}

- (void)setListIDs:(NSArray *)listIDs {
    [self performMutation:^(void) {
        ADLListCollection* collection = self.defaultCollection;
        [collection mutateListsSet:^(NSMutableOrderedSet* set) {
            [set removeAllObjects];
            for(NSManagedObjectID* listID in listIDs) {
                ADLList* list = (ADLList*)[self.managedObjectContext objectWithID:listID];
                [set addObject:list];
            }
        }];
    }];
}

- (NSString*)titleOfList:(ADLListID*)listID {
    ADLList* list = (ADLList*)[self.managedObjectContext objectWithID:listID];
    return list.title;
}

- (void)setTitle:(NSString*)title ofList:(ADLListID*)listID {
    [self performMutation:^(void) {
        ADLList* list = (ADLList*)[self.managedObjectContext objectWithID:listID];
        list.title = title;
    }];
}

- (void)setText:(NSString*)text ofList:(ADLListID*)listID {
    [self performMutation:^(void) {
        ADLList* list = (ADLList*)[self.managedObjectContext objectWithID:listID];
        list.body = text;
    }];
}

- (void)addListAtIndex:(NSUInteger)index {
    [self addList:^(ADLList* list) {
        list.title = @"Untitled";
    } toCollection:self.defaultCollection atIndex:index];
}

#pragma mark Change Processing

- (void)addCollectionChangedListener:(id <ADLCollectionChangedListener>)listener {
    [self.collectionChangedListeners addObject:listener];
}

- (void)removeCollectionChangedListener:(id <ADLCollectionChangedListener>)listener {
    [self.collectionChangedListeners removeObject:listener];
}


- (void)addListChangedListener:(id <ADLListChangedListener>)listener {
    [self.listChangedListeners addObject:listener];
}

- (void)removeListChangedListener:(id <ADLListChangedListener>)listener {
    [self.listChangedListeners removeObject:listener];
}

- (void)modelChangesSaved:(NSNotification*)notification {
    NSArray* insertedObjects = [[notification userInfo] objectForKey:NSInsertedObjectsKey];
    NSArray* updatedObjects = [[notification userInfo] objectForKey:NSUpdatedObjectsKey];
    NSArray* deletedObjects = [[notification userInfo] objectForKey:NSDeletedObjectsKey];
    
    NSMutableArray* insertedLists = [NSMutableArray array];
    NSMutableArray* updatedLists = [NSMutableArray array];
    NSMutableArray* deletedLists = [NSMutableArray array];
    
    BOOL changedCollection = NO;
    
    for(NSManagedObject* object in insertedObjects) {
        if([object isKindOfClass:[ADLList class]]) {
            [insertedLists addObject:object.objectID];
        }
    }
    for(NSManagedObject* object in updatedObjects) {
        if([object isKindOfClass:[ADLList class]]) {
            ADLList* list = (ADLList*)object;
            [updatedLists addObject:object.objectID];
            for(id <ADLListChangedListener> listener in self.listChangedListeners) {
                [listener changedListWithID:list.objectID bodyText:list.body];
            }
        }
        else if([object isKindOfClass:[ADLListCollection class]]) {
            changedCollection = YES;
        }
    }
    for(NSManagedObject* object in deletedObjects) {
        if([object isKindOfClass:[ADLList class]]) {
            [deletedLists addObject:object.objectID];
        }
    }
    
    if((insertedLists.count + updatedLists.count + deletedLists.count > 0) || changedCollection) {
        for(id <ADLCollectionChangedListener> listener in self.collectionChangedListeners) {
            if([listener respondsToSelector:@selector(changedListsIDsTo:)]) {
                [listener changedListsIDsTo:self.listIDs];
            }
        }
    }
    
}

- (ADLListID*)currentlySavedListID {
    NSData* data = [[NSUserDefaults standardUserDefaults] objectForKey:kADLSelectedListKey];
    if(data == nil) {
        return nil;
    }
    else {
        NSURL* url = [NSUnarchiver unarchiveObjectWithData:data];
        NSPersistentStoreCoordinator* persistentStoreCoordinator = self.managedObjectContext.persistentStoreCoordinator;
        NSManagedObjectID* currentListID = [persistentStoreCoordinator managedObjectIDForURIRepresentation:url];
        return currentListID;
    }
}

- (void)setSelectedListID:(ADLListID*)listID {
    ADLListID* currentListID = [self currentlySavedListID];
    if(![currentListID isEqual:listID]) {
        NSData* data = [NSArchiver archivedDataWithRootObject:listID.URIRepresentation];
        [[NSUserDefaults standardUserDefaults] setObject:data forKey:kADLSelectedListKey];
        for(id <ADLCollectionChangedListener> listener in self.collectionChangedListeners) {
            if([listener respondsToSelector:@selector(changedSelectedListIDTo:)]) {
                [listener changedSelectedListIDTo:listID];
            }
        }
    }
}

- (NSString*)bodyTextForListID:(ADLListID*)listID {
    ADLList* list = (ADLList*)[self.managedObjectContext objectWithID:listID];
    return list.body;
}

- (ADLListID*)setupDefaultSelection {
    
    NSArray* lists = self.listIDs;
    if (lists.count > 0) {
        ADLListID* result = [lists objectAtIndex:0];
        self.selectedListID = result;
        return result;
    }
    else {
        NSAssert(NO, @"Ended up with no lists");
        return nil;
    }
}

- (ADLListID*)selectedListID {
    NSManagedObjectID* listID = [self currentlySavedListID];
    if([self.lists containsObject:listID]) {
        return listID;
    }
    else {
        return [self setupDefaultSelection];
    }
    
}

@end
