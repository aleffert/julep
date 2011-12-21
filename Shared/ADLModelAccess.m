//
//  ADLModelAccess.m
//  julep
//
//  Created by Akiva Leffert on 9/27/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "ADLModelAccess.h"

#import <CalendarStore/CalendarStore.h>

#import "ADLConcreteItem.h"
#import "ADLItem.h"
#import "ADLList.h"
#import "ADLList+CollectionAdditions.h"
#import "ADLListCollection.h"
#import "ADLListCollection+CollectionAdditions.h"
#import "CalCalendarStore+ADLAdditions.h"
#import "NSArray+ADLAdditions.h"
#import "NSDate+ADLAdditions.h"
#import "NSDictionary+ADLAdditions.h"

static NSString* kADLSelectedListKey = @"kADLSelectedListKey";

NSString* kADLItemPasteboardType = @"com.akivaleffert.julep.ItemPasteboardType";

@interface ADLModelAccess ()

@property (retain, nonatomic) NSManagedObjectContext* managedObjectContext;
@property (readonly, nonatomic) ADLListCollection* defaultCollection;
@property (retain, nonatomic) NSManagedObjectID* defaultCollectionID;
@property (retain, nonatomic) NSMutableArray* collectionChangedListeners;
@property (retain, nonatomic) NSMutableDictionary* listChangedListeners;

@property (retain, nonatomic) NSTimer* clearRecentlyModifiedTimer;
@property (copy, nonatomic) NSArray* recentlyModifiedObjects;
- (void)stopClearRecentlyModifiedTimer;

- (ADLListID*)setupDefaultSelection;

- (BOOL)isTaskStale:(CalTask*)task;

- (void)deleteTrackedListWithID:(ADLListID*)listID;
- (ADLList*)listForCalendarUID:(NSString*)uid;

- (void)addItem:(void (^)(ADLItem* item))defaults toList:(ADLList*)list atIndex:(NSUInteger)index;
- (ADLItem*)itemForTaskUID:(NSString*)uid;
- (void)deleteTrackedItemWithID:(ADLItemID*)itemID;

- (void)addList:(void (^)(ADLList* newList))defaults toCollection:(ADLListCollection*)collection atIndex:(NSUInteger)index;

- (ADLItemID*)addItemWithTitle:(NSString*)title toListWithID:(ADLListID*)listID atIndex:(NSUInteger)index;
@end

static NSString* kADLListEntityName = @"List";
static NSString* kADLCollectionEntityName = @"ListCollection";
static NSString* kADLListItemEntityName= @"Item";

@implementation ADLModelAccess

@synthesize managedObjectContext = mManagedObjectContext;
@synthesize defaultCollectionID = mDefaultCollectionID;
@synthesize collectionChangedListeners = mCollectionChangedListeners;
@synthesize listChangedListeners = mListChangedListeners;
@synthesize delegate = mDelegate;
@synthesize undoManager = mUndoManager;
@synthesize clearRecentlyModifiedTimer = mClearRecentlyModifiedTimer;
@synthesize recentlyModifiedObjects = mRecentlyModifiedObjects;

- (ADLModelAccess*)initWithManagedObjectContext:(NSManagedObjectContext*)context {
    self = [super init];
    if(self) {
        self.managedObjectContext = context;
        self.collectionChangedListeners = [NSMutableArray nonretainingMutableArray];
        self.listChangedListeners = [NSMutableDictionary dictionary];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(modelChangesSaved:) name:NSManagedObjectContextDidSaveNotification object:self.managedObjectContext];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(calendarsChanged:) name:CalCalendarsChangedNotification object:[CalCalendarStore defaultCalendarStore]];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(calendarsChangedExternally:) name:CalCalendarsChangedExternallyNotification object:[CalCalendarStore defaultCalendarStore]];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tasksChanged:) name:CalTasksChangedNotification object:[CalCalendarStore defaultCalendarStore]];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tasksChangedExternally:) name:CalTasksChangedExternallyNotification object:[CalCalendarStore defaultCalendarStore]];
        
        self.undoManager = [[[NSUndoManager alloc] init] autorelease];
    }
    return self;
}

- (void)dealloc {
    [self stopClearRecentlyModifiedTimer];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.collectionChangedListeners = nil;
    self.listChangedListeners = nil;
    self.defaultCollectionID = nil;
    self.managedObjectContext = nil;
    [super dealloc];
}

- (NSEntityDescription*)listEntityDescription {
    return [NSEntityDescription entityForName:kADLListEntityName inManagedObjectContext:self.managedObjectContext];
}

- (NSEntityDescription*)listItemEntityDescription {
    return [NSEntityDescription entityForName:kADLListItemEntityName inManagedObjectContext:self.managedObjectContext];
}

- (NSEntityDescription*)collectionEntityDescription {
    return [NSEntityDescription entityForName:kADLCollectionEntityName inManagedObjectContext:self.managedObjectContext];
}

- (void)performUndoBlock:(void (^)(void))operation {
    operation();
}

- (void)performMutation:(void (^)(void))mutator {
    mutator();
    [self.delegate modelDidMutate:self];
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

- (BOOL)hasTaskWithUID:(NSString*)uid {
    // We'd like to return nil
    
    CalCalendarStore* store = [CalCalendarStore defaultCalendarStore];
    NSArray* reminderCalendars = [store reminderCalendars];
    NSPredicate* calendarsPredicate = [CalCalendarStore taskPredicateWithCalendars: reminderCalendars];
    NSArray* tasks = [store tasksWithPredicate:calendarsPredicate];
    NSPredicate* uidPredicate = [NSPredicate predicateWithFormat:@"uid like %@", uid];
    NSArray* filteredTasks = [tasks filteredArrayUsingPredicate:uidPredicate];
    if(filteredTasks.count > 0) {
        CalTask* task = [filteredTasks objectAtIndex:0];
        return ![self isTaskStale:task];
    }
    else {
        return NO;
    }
}

- (void)populateDefaults {
    // Create the collection
    [self performMutation:^(void) {
        ADLListCollection* collection = [[ADLListCollection alloc] initWithEntity:self.collectionEntityDescription insertIntoManagedObjectContext:self.managedObjectContext];
        collection.name = @"Default";
        [collection release];
    
    }];
    
    [self syncWithDataStore];
}

- (void)syncWithDataStore {
    CalCalendarStore* store = [CalCalendarStore defaultCalendarStore];
    NSArray* reminderCalendars = [store reminderCalendars];
    NSUInteger i = 0;
    
    // Add any new calendars
    for(CalCalendar* calendar in reminderCalendars) {
        // Look for a calendar with this uid
        ADLList* existingList = [self listForCalendarUID:calendar.uid];
        if(existingList == nil) {
            [self addList:^(ADLList* list) {
                list.uid = calendar.uid;
            } toCollection:self.defaultCollection atIndex:i];
        }
        i++;
    };
    
    // Add any new items
    NSDate* sinceDate = [NSDate yesterdayMorning];
    NSPredicate* uncompletedPredicate = [CalCalendarStore taskPredicateWithUncompletedTasks:reminderCalendars];
    NSPredicate* recentlyCompletedPredicate = [CalCalendarStore taskPredicateWithTasksCompletedSince:sinceDate calendars:reminderCalendars];
    NSArray* uncompletedTasks = [store tasksWithPredicate:uncompletedPredicate];
    NSArray* recentlyCompletedTasks = [store tasksWithPredicate:recentlyCompletedPredicate];
    NSArray* tasks = [uncompletedTasks arrayByAddingObjectsFromArray:recentlyCompletedTasks];
    for (CalTask* task in tasks) {
        // Look for a task with this uid
        ADLItem* existingItem = [self itemForTaskUID:task.uid];
        if(existingItem == nil) {
            ADLList* list = [self listForCalendarUID:task.calendar.uid];
            [self addItem:^(ADLItem* item) {
                item.uid = task.uid;
            } toList: list atIndex:0];
        }
    }
    
    // Remove extras
    for(ADLList* list in self.defaultCollection.lists) {
        NSArray* items = [NSArray arrayWithArray:list.items.array];
        for(ADLItem* item in items) {
            if(![self hasTaskWithUID:item.uid]) {
                [self deleteTrackedItemWithID:item.objectID];
            }
        }
        CalCalendar* calendar = [store calendarWithUID:list.uid];
        if(calendar == nil) {
            [self deleteTrackedListWithID:list.objectID];
        }
    }
}

- (BOOL)isTaskStale:(CalTask*)task {
    return task.isCompleted && ([task.completedDate compare:[NSDate yesterdayMorning]] == NSOrderedAscending);
}

- (ADLList*)listForCalendarUID:(NSString*)uid {
    NSFetchRequest* request = [[NSFetchRequest alloc] init];
    request.entity = self.listEntityDescription;
    request.predicate = [NSPredicate predicateWithFormat:@"uid == %@", uid];
    NSError* error = nil;
    NSArray* results = [self.managedObjectContext executeFetchRequest:request error:&error];
    [request release];
    NSAssert(error == nil, @"Unable to look for calendar with uid");
    
    if(results.count == 0) {
        return nil;
    }
    else {
        NSAssert(results.count == 1, @"Consistency violation. Multiple lists with the same uid.");
        return [results objectAtIndex:0];
    }
}

- (NSArray*)itemIDsForList:(ADLListID *)listID {
    ADLList* list = (ADLList*)[self.managedObjectContext objectWithID:listID];
    NSMutableArray* result = [NSMutableArray array];
    for(ADLItem* item in list.items) {
        [result addObject:item.objectID];
    }
    return result;
}

- (NSUInteger)indexOfItem:(ADLItemID*)itemID inList:(ADLListID*)listID {
    return [[self itemIDsForList:listID] indexOfObject:itemID];
}

- (ADLItemID*)moveItem:(ADLItemID*)itemID toIndex:(NSUInteger)index ofList:(ADLListID*)listID asReorder:(BOOL)asReorder {
    ADLItem* item = (ADLItem*)[self.managedObjectContext objectWithID:itemID];
    ADLList* currentList = item.owner;
    NSUInteger currentIndex = [self indexOfItem:itemID inList:listID];
    ADLList* newList = (ADLList*)[self.managedObjectContext objectWithID:listID];
    BOOL movingBackward = index < currentIndex;
    ADLItemID* finalItemID = itemID;
    
    NSUInteger adjustedIndex = movingBackward ? index : index - 1;
    NSUInteger adjustedCurrentIndex = movingBackward ? currentIndex + 1 : currentIndex;

    if(asReorder) {
        if([newList.items containsObject:item]) {
            [newList mutateItemsSet:^(NSMutableOrderedSet* set) {
                [set moveObjectsAtIndexes:[NSIndexSet indexSetWithIndex:currentIndex] toIndex:adjustedIndex];
            }];
        }
        else {
            [newList mutateItemsSet:^(NSMutableOrderedSet* set) {
                [set insertObject:item atIndex:index];
            }];
            NSAssert(NO, @"don't support dropping across lists");
        }
        
        NSError* error = nil;
        [self.managedObjectContext save:&error];
        NSAssert(error == nil, @"Error saving after move");
            
    }
    else {
        NSString* uid = item.uid;
        [self deleteTrackedItemWithID:itemID];
        [self addItem:^(ADLItem* newItem) {
            newItem.uid = uid;
        } toList:newList atIndex:adjustedIndex];
        finalItemID = [self itemForTaskUID:uid].objectID;
    }
    
    self.undoManager.actionName = @"Move Item";

    __block ADLModelAccess* owner = self;
    [self.undoManager registerUndoWithTarget:self selector:@selector(performUndoBlock:) object:[[^(void) {
        [owner moveItem:finalItemID toIndex:adjustedCurrentIndex ofList:currentList.objectID asReorder:YES];
    } copy] autorelease]];
    
    return finalItemID;
}

- (ADLListID*)listIDForURL:(NSURL*)url {
    NSPersistentStoreCoordinator* persistentStoreCoordinator = self.managedObjectContext.persistentStoreCoordinator;
    NSManagedObjectID* listID = [persistentStoreCoordinator managedObjectIDForURIRepresentation:url];
    return listID;
}

- (ADLItemID*)itemIDForURL:(NSURL*)url {
    NSPersistentStoreCoordinator* persistentStoreCoordinator = self.managedObjectContext.persistentStoreCoordinator;
    NSManagedObjectID* itemID = [persistentStoreCoordinator managedObjectIDForURIRepresentation:url];
    return itemID;
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

- (void)deleteTrackedListWithID:(ADLListID*)listID {
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



- (void)stopTrackingCalendarIfNecessary:(NSString*)uid {
    // Find the associated calendar
    ADLList* list = [self listForCalendarUID:uid];
    // If it exists then delete it
    if(list != nil) {
        [self deleteTrackedListWithID:list.objectID];
    }
}

- (void)stopTrackingTaskIfNecessary:(NSString*)uid {
    ADLItem* item  = [self itemForTaskUID:uid];
    if(item != nil) {
        [self deleteTrackedItemWithID:item.objectID];
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
    CalCalendar* calendar = [[CalCalendarStore defaultCalendarStore] calendarWithUID:list.uid];
    return calendar.title;
}

- (BOOL)showsCountInBadgeForList:(ADLListID*)listID {
    ADLList* list = (ADLList*)[self.managedObjectContext objectWithID:listID];
    return list.showsCountInBadge;
}

- (void)setTitle:(NSString*)title ofList:(ADLListID*)listID {
    self.undoManager.actionName = @"Title Change";
    __block ADLModelAccess* owner = self;
    NSString* currentTitle = [self titleOfList:listID];
    [self.undoManager registerUndoWithTarget:self selector:@selector(performUndoBlock:) object:[[^(void) {
        [owner setTitle:currentTitle ofList:listID];
    } copy] autorelease]];
    ADLList* list = (ADLList*)[self.managedObjectContext objectWithID:listID];
    CalCalendar* calendar = [[CalCalendarStore defaultCalendarStore] calendarWithUID:list.uid];
    calendar.title = title;
    NSError* error = nil;
    [[CalCalendarStore defaultCalendarStore] saveCalendar:calendar error:&error];
    NSAssert(error == nil, @"Error saving calendar title change");
}

- (void)setShowsCountInBadge:(BOOL)showsCountInBadge forList:(ADLListID*)listID {
    ADLList* list = (ADLList*)[self.managedObjectContext objectWithID:listID];
    [self performMutation:^(void) {
        list.showsCountInBadge = showsCountInBadge;
    }];
}

- (BOOL)completionStatusOfItem:(ADLItemID*)itemID {
    ADLItem* item = (ADLItem*)[self.managedObjectContext objectWithID:itemID];
    CalTask* task = [[CalCalendarStore defaultCalendarStore] taskWithUID:item.uid];
    return task.isCompleted;
}

- (void)setCompletionStatus:(BOOL)status ofItem:(NSManagedObjectID *)itemID {
    self.undoManager.actionName = @"Completion Change";
    __block ADLModelAccess* owner = self;
    BOOL currentStatus = [self completionStatusOfItem:itemID];
    ADLItem* item = (ADLItem*)[self.managedObjectContext objectWithID:itemID];
    NSUInteger currentIndex = [self indexOfItem:itemID inList:item.owner.objectID];
    ADLListID* listID = item.owner.objectID;
    [self.undoManager registerUndoWithTarget:self selector:@selector(performUndoBlock:) object:[[^(void) {
        ADLItemID* newItemID = [[self itemIDsForList:listID] objectAtIndex:currentIndex];
        [owner setCompletionStatus:currentStatus ofItem:newItemID];
    } copy] autorelease]];
    CalTask* task = [[CalCalendarStore defaultCalendarStore] taskWithUID:item.uid];
    task.isCompleted = status;
    NSError* error = nil;
    [[CalCalendarStore defaultCalendarStore] saveTask:task error:&error];
    NSAssert(error == nil, @"Error saving completion status change");
}

- (NSString*)titleOfItem:(ADLItemID*)itemID {
    ADLItem* item = (ADLItem*)[self.managedObjectContext objectWithID:itemID];
    CalTask* task = [[CalCalendarStore defaultCalendarStore] taskWithUID:item.uid];
    return task.title;
}

- (void)setTitle:(NSString *)title ofItem:(NSManagedObjectID *)itemID {
    self.undoManager.actionName = @"Title Change";
    __block ADLModelAccess* owner = self;
    NSString* currentTitle = [self titleOfItem:itemID];
    ADLItem* item = (ADLItem*)[self.managedObjectContext objectWithID:itemID];
    NSUInteger currentIndex = [self indexOfItem:itemID inList:item.owner.objectID];
    ADLListID* listID = item.owner.objectID;
    
    [self.undoManager registerUndoWithTarget:self selector:@selector(performUndoBlock:) object:[[^(void) {
        ADLItemID* newItemID = [[self itemIDsForList:listID] objectAtIndex:currentIndex];
        [owner setTitle:currentTitle ofItem:newItemID];
    } copy] autorelease]];
    CalTask* task = [[CalCalendarStore defaultCalendarStore] taskWithUID:item.uid];
    task.title = title;
    NSError* error = nil;
    [[CalCalendarStore defaultCalendarStore] saveTask:task error:&error];
    NSAssert(error == nil, @"Error saving item title change");
}

- (id)pasteboardRepresentationOfItemID:(ADLItemID*)itemID {
    ADLItem* item = (ADLItem*)[self.managedObjectContext objectWithID:itemID];
    CalTask* task = [[CalCalendarStore defaultCalendarStore] taskWithUID:item.uid];
    ADLConcreteItem* concreteItem = [ADLConcreteItem itemWithTask:task];
    return concreteItem;
}

- (void)addListAtIndex:(NSUInteger)index {
    NSLog(@"dead. cry");
}

- (void)addItem:(void (^)(ADLItem* item))defaults toList:(ADLList*)list atIndex:(NSUInteger)index {
    [self performMutation:^(void) {
        ADLItem* item = [[ADLItem alloc] initWithEntity:self.listItemEntityDescription insertIntoManagedObjectContext:self.managedObjectContext];
        [list mutateItemsSet:^(NSMutableOrderedSet* set) {
            [set insertObject:item atIndex:index];
        }];
        defaults(item);
        [item release];

    }];
}

- (ADLItem*)itemForTaskUID:(NSString*)uid {
    NSFetchRequest* request = [[NSFetchRequest alloc] init];
    request.entity = self.listItemEntityDescription;
    request.predicate = [NSPredicate predicateWithFormat:@"uid == %@", uid];
    NSError* error = nil;
    NSArray* results = [self.managedObjectContext executeFetchRequest:request error:&error];
    [request release];
    NSAssert(error == nil, @"Unable to look for calendar with uid");
    
    if(results.count == 0) {
        return nil;
    }
    else {
        NSAssert(results.count == 1, @"Consistency violation. Multiple items with the same uid.");
        return [results objectAtIndex:0];
    }

}

- (void)deleteTrackedItemWithID:(ADLItemID*)itemID {
    ADLItem* item = (ADLItem*)[self.managedObjectContext objectWithID:itemID];
    ADLList* owningList = item.owner;

    [self performMutation:^(void) {
        [owningList mutateItemsSet:^(NSMutableOrderedSet* set) {
            [set removeObject:item];
        }];
        [self.managedObjectContext deleteObject:item];
    }];
}

- (ADLItemID*)addItemWithInitializer:(void(^)(CalTask* task))initializer toListWithID:(ADLListID*)listID atIndex:(NSUInteger)index {
    ADLList* list = (ADLList*)[self.managedObjectContext objectWithID:listID];
    CalCalendarStore* store = [CalCalendarStore defaultCalendarStore];
    CalTask* task = [CalTask task];
    initializer(task);
    task.calendar = [store calendarWithUID:list.uid];
    
    __block ADLModelAccess* owner = self;
    __block ADLItem* newItem = nil;
    [self addItem:^(ADLItem* item) {
        newItem = item;
        item.uid = task.uid;
    } toList:list atIndex:index];
    
    [self.undoManager registerUndoWithTarget:self selector:@selector(performUndoBlock:) object:[[^(void) {
        [owner deleteItemWithID:newItem.objectID];
    } copy] autorelease]];
    self.undoManager.actionName = @"Create Todo";
    
    NSError* error = nil;
    [store saveTask:task error:&error];
    NSAssert(error == nil, @"Error creating new item");
    
    return newItem.objectID;
}

- (ADLItemID*)addItemWithTitle:(NSString*)title toListWithID:(ADLListID*)listID {
    return [self addItemWithTitle:title toListWithID:listID atIndex:0];
}

- (ADLItemID*)addItemWithTitle:(NSString*)title toListWithID:(ADLListID*)listID atIndex:(NSUInteger)index {
    return [self addItemWithInitializer:^(CalTask* task) {
        task.title = title;
    } toListWithID:listID atIndex:index];
}

- (ADLItemID*)addConcreteItem:(ADLConcreteItem*)concreteItem toListWithID:(ADLListID*)listID atIndex:(NSUInteger)index {
    return [self addItemWithInitializer:^(CalTask* task) {
        task.title = concreteItem.title;
        task.isCompleted = concreteItem.completionStatus;
        task.dueDate = concreteItem.dueDate;
        task.completedDate = concreteItem.completedDate;
        task.priority = concreteItem.priority;
        task.notes = concreteItem.notes;
        task.url = concreteItem.url;
    } toListWithID:listID atIndex:index];
}

- (void)deleteItemWithID:(ADLItemID*)itemID {
    ADLItem* item = (ADLItem*)[self.managedObjectContext objectWithID:itemID];
    CalCalendarStore* store = [CalCalendarStore defaultCalendarStore];
    CalTask* task = [store taskWithUID:item.uid];
    NSError* error = nil;
    
    NSString* title = [self titleOfItem:itemID];
    ADLListID* listID = item.owner.objectID;
    NSUInteger index = [item.owner.items indexOfObject:item];
    __block ADLModelAccess* owner = self;
    BOOL currentCompletionStatus = [self completionStatusOfItem:itemID];
    
    [self.undoManager registerUndoWithTarget:self selector:@selector(performUndoBlock:) object:[[^(void) {
        ADLItemID* newItemID = [owner addItemWithTitle:title toListWithID:listID atIndex:index];
        ADLItem* newItem = (ADLItem*)[owner.managedObjectContext objectWithID:newItemID];
        CalTask* newTask = [store taskWithUID:newItem.uid];
        newTask.isCompleted = currentCompletionStatus;

        NSError* undoError = nil;
        [store saveTask:newTask error:&undoError];
        NSAssert(undoError == nil, @"error undoing delete");
        
    } copy] autorelease]];
    self.undoManager.actionName = @"Delete Todo";
    
    [store removeTask:task error:&error];
    NSAssert(error == nil, @"Error deleting item");
}

#pragma mark Change Processing

- (void)addCollectionChangedListener:(id <ADLCollectionChangedListener>)listener {
    [self.collectionChangedListeners addObject:listener];
}

- (void)removeCollectionChangedListener:(id <ADLCollectionChangedListener>)listener {
    [self.collectionChangedListeners removeObject:listener];
}


- (void)addChangeListener:(id <ADLListChangedListener>)listener forList:(ADLListID *)list {
    NSMutableSet* listeners = [self.listChangedListeners objectForKey:list];
    if(listeners == nil) {
        listeners = [NSMutableSet set];
        [self.listChangedListeners setObject:listeners forKey:list];
    }
    [listeners addObject:listener];
}

- (void)removeChangeListener:(id <ADLListChangedListener>)listener forList:(ADLListID*)list {
    NSMutableSet* listeners = [self.listChangedListeners objectForKey:list];
    [listeners removeObject:listener];
}


- (void)notifyCollectionChangedListeners {
    for(id <ADLCollectionChangedListener> listener in self.collectionChangedListeners) {
        if([listener respondsToSelector:@selector(changedListsIDsTo:)]) {
            [listener changedListsIDsTo:self.listIDs];
        }
    }
}

- (void)notifyChangeListenersForListID:(ADLListID*)listID {
    NSSet* listeners = [self.listChangedListeners objectForKey:listID];
    if(listeners != nil) {
        NSArray* items = [self itemIDsForList:listID];
        for(id <ADLListChangedListener> listener in listeners) {
            [listener list:listID changedItemIDsTo:items];
        }
    }
}

- (void)notifyChangeListenersForCalendarUIDs:(NSArray*)lists {
    for(NSString* uid in lists) {
        ADLList* list = [self listForCalendarUID:uid];
        [self notifyChangeListenersForListID:list.objectID];
    }
}

- (void)modelChangesSaved:(NSNotification*)notification {
    NSSet* insertedObjects = [[notification userInfo] objectForKey:NSInsertedObjectsKey];
    NSSet* updatedObjects = [[notification userInfo] objectForKey:NSUpdatedObjectsKey];
    NSSet* deletedObjects = [[notification userInfo] objectForKey:NSDeletedObjectsKey];
    
    BOOL changedCollection = NO;
    NSMutableArray* changedLists = [NSMutableArray array];
    
    for(NSManagedObject* object in insertedObjects) {
        if([object isKindOfClass:[ADLList class]]) {
            [changedLists addObject:[object valueForKey:@"uid"]];
        }
    }
    for(NSManagedObject* object in updatedObjects) {
        if([object isKindOfClass:[ADLList class]]) {
            [changedLists addObject:[object valueForKey:@"uid"]];
        }
        else if([object isKindOfClass:[ADLListCollection class]]) {
            changedCollection = YES;
        }
    }
    for(NSManagedObject* object in deletedObjects) {
        if([object isKindOfClass:[ADLList class]]) {
            [changedLists addObject:[object valueForKey:@"uid"]];
        }
    }
    
    if(changedCollection) {
        [self notifyCollectionChangedListeners];
    }
    [self notifyChangeListenersForCalendarUIDs:changedLists];
    
}

- (void)stopClearRecentlyModifiedTimer {
    [self.clearRecentlyModifiedTimer invalidate];
    self.clearRecentlyModifiedTimer = nil;
}

- (void)clearRecentlyModified {
    self.recentlyModifiedObjects = nil;
    self.clearRecentlyModifiedTimer = nil;
}

- (void)spawnClearRecentlyModifiedTimer {
    [self stopClearRecentlyModifiedTimer];
    self.clearRecentlyModifiedTimer = [NSTimer scheduledTimerWithTimeInterval:.8 target:self selector:@selector(clearRecentlyModified) userInfo:nil repeats:NO];
}

- (void)calendarsChanged:(NSNotification*)notification {
    CalCalendarStore* store = [CalCalendarStore defaultCalendarStore];
    ADLListCollection* collection = self.defaultCollection;
    
    NSArray* insertedObjects = [[notification userInfo] objectForKey:CalInsertedRecordsKey];
    NSArray* updatedObjects = [[notification userInfo] objectForKey:CalUpdatedRecordsKey];
    NSArray* deletedObjects = [[notification userInfo] objectForKey:CalDeletedRecordsKey];
    
    for(NSString* uid in insertedObjects) {
        CalCalendar* calendar = [store calendarWithUID:uid];
        if([store isReminderCalendar:calendar]) {
            [self addList:^(ADLList* list) {
                list.uid = calendar.uid;
            } toCollection:collection atIndex:self.listCount];
        }
    }
    
    for(NSString* uid in deletedObjects) {
        [self stopTrackingCalendarIfNecessary:uid];
    }
    
    for(NSString* uid in updatedObjects) {
        CalCalendar* calendar = [store calendarWithUID:uid];
        // A calendar can become a reminder calendar
        if([self listForCalendarUID:uid] == nil && [store isReminderCalendar:calendar]) {
            [self addList:^(ADLList* list) {
                list.uid = calendar.uid;
            } toCollection:collection atIndex:self.listCount];
        }
    }
    
    BOOL updatedCalendars = updatedObjects.count > 0;
    if(updatedCalendars) {
        [self notifyCollectionChangedListeners];
    }
    
    for(NSString* uid in deletedObjects) {
        [self stopTrackingCalendarIfNecessary:uid];
    }
}

- (void)calendarsChangedExternally:(NSNotification*)notification {
    [self calendarsChanged:notification];
}

- (void)tasksChanged:(NSNotification*)notification {
    CalCalendarStore* store = [CalCalendarStore defaultCalendarStore];
    NSMutableSet* updatedCalendars = [NSMutableArray array];
    
    NSArray* insertedObjects = [[notification userInfo] objectForKey:CalInsertedRecordsKey];
    NSArray* updatedObjects = [[notification userInfo] objectForKey:CalUpdatedRecordsKey];
    NSArray* deletedObjects = [[notification userInfo] objectForKey:CalDeletedRecordsKey];
    for(NSString* uid in insertedObjects) {
        CalTask* task = [store taskWithUID:uid];
        ADLList* list = [self listForCalendarUID:task.calendar.uid];
        if(![self isTaskStale:task] && ([self itemForTaskUID:uid] == nil)) {
            [self addItem:^(ADLItem* item) {
                item.uid = task.uid;
            } toList:list atIndex:0];
        }
        [updatedCalendars addObject:task.calendar.uid];
    }
    
    for(NSString* uid in deletedObjects) {
        ADLItem* item = [self itemForTaskUID:uid];
        if(item != nil) {
            [updatedCalendars addObject:item.owner.uid];
        }
        [self stopTrackingTaskIfNecessary:uid];
    }
    
    for(NSString* uid in updatedObjects) {
        if([self hasTaskWithUID:uid]) {
            CalTask* task = [store taskWithUID:uid];
            [updatedCalendars addObject:task.calendar.uid];
        }
    }
    
    [self notifyChangeListenersForCalendarUIDs:updatedCalendars.allObjects];
    
    if(self.recentlyModifiedObjects == nil) {
        self.recentlyModifiedObjects = insertedObjects;
    }
    else {
        self.recentlyModifiedObjects = [self.recentlyModifiedObjects arrayByAddingObjectsFromArray: insertedObjects];
    }
    
    if(self.recentlyModifiedObjects == nil) {
        self.recentlyModifiedObjects = updatedObjects;
    }
    else {
        self.recentlyModifiedObjects = [self.recentlyModifiedObjects arrayByAddingObjectsFromArray: updatedObjects];
    }
    
    [self spawnClearRecentlyModifiedTimer];
}

- (void)tasksChangedExternally:(NSNotification*)notification {
    // We might get this without any real changes because iCal modifies records for some reason.
    // Ignore it if we think it's a change from us
    NSArray* updatedRecords = [[notification userInfo] objectForKey:CalUpdatedRecordsKey];
    BOOL foundDifferentChanges = NO;
    for(id uid in updatedRecords) {
        foundDifferentChanges = foundDifferentChanges || ![self.recentlyModifiedObjects containsObject:uid];
    }
    if(foundDifferentChanges) {
        NSLog(@"removing all actions for changes to %@", self.recentlyModifiedObjects);
        [self.undoManager removeAllActions];
    }
    else {
        [self stopClearRecentlyModifiedTimer];
        self.recentlyModifiedObjects = nil;
    }
    [self tasksChanged:notification];
}

- (ADLListID*)currentlySavedListID {
    NSData* data = [[NSUserDefaults standardUserDefaults] objectForKey:kADLSelectedListKey];
    if(data == nil) {
        return nil;
    }
    else {
        NSURL* url = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        NSPersistentStoreCoordinator* persistentStoreCoordinator = self.managedObjectContext.persistentStoreCoordinator;
        NSManagedObjectID* currentListID = [persistentStoreCoordinator managedObjectIDForURIRepresentation:url];
        return currentListID;
    }
}

- (void)setSelectedListID:(ADLListID*)listID {
    ADLListID* currentListID = [self currentlySavedListID];
    if(![currentListID isEqual:listID]) {
        NSData* data = [NSKeyedArchiver archivedDataWithRootObject:listID.URIRepresentation];
        [[NSUserDefaults standardUserDefaults] setObject:data forKey:kADLSelectedListKey];
        for(id <ADLCollectionChangedListener> listener in self.collectionChangedListeners) {
            if([listener respondsToSelector:@selector(changedSelectedListIDTo:)]) {
                [listener changedSelectedListIDTo:listID];
            }
        }
    }
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
    if([self.listIDs containsObject:listID]) {
        return listID;
    }
    else {
        return [self setupDefaultSelection];
    }
    
}

@end
