//
//  ADLModelAccess.h
//  julep
//
//  Created by Akiva Leffert on 9/27/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

typedef NSManagedObjectID ADLListID;
typedef NSManagedObjectID ADLItemID;

@protocol ADLCollectionChangedListener;
@protocol ADLListChangedListener;
@protocol ADLModelAccessDelegate;
@protocol ADLModelChangedListener;

@class ADLConcreteItem;

@interface ADLModelAccess : NSObject {
    NSManagedObjectContext* mManagedObjectContext;
    NSManagedObjectID* mDefaultCollectionID;
    id <ADLModelAccessDelegate> mDelegate;
    NSMutableArray* mCollectionChangedListeners;
    NSMutableDictionary* mListChangedListeners;
    NSUndoManager* mUndoManager;
}

- (ADLModelAccess*)initWithManagedObjectContext:(NSManagedObjectContext*)context;
@property (assign, nonatomic) id <ADLModelAccessDelegate> delegate;
@property (retain, nonatomic) NSUndoManager* undoManager;

- (void)populateDefaults;
- (void)syncWithDataStore;

@property (readonly, nonatomic) NSUInteger listCount;
@property (copy, nonatomic) NSArray* listIDs;

- (NSUInteger)unfinishedCountForBadge;

- (ADLListID*)listOwningItem:(ADLItemID*)itemID;

- (ADLItemID*)itemIDForURL:(NSURL*)url;
- (NSUInteger)indexOfItem:(ADLItemID*)itemID inList:(ADLListID*)listID;

- (ADLListID*)listIDForURL:(NSURL*)url;
- (NSString*)titleOfList:(ADLListID*)listID;
- (BOOL)showsCountInBadgeForList:(ADLListID*)listID;


- (NSUInteger)indexOfItem:(ADLItemID*)itemID inList:(ADLListID*)listID;
- (NSString*)titleOfItem:(ADLItemID*)itemID;
- (BOOL)completionStatusOfItem:(ADLItemID*)itemID;

- (NSArray*)itemIDsForList:(ADLListID*)listID;

- (id)pasteboardRepresentationOfItemID:(ADLItemID*)itemID;

@property (retain, nonatomic) ADLListID* selectedListID;

- (NSArray*)itemsWithSearchString:(NSString*)query;

// Change processing

- (void)addModelChangedListener:(id <ADLModelChangedListener>)listener;
- (void)removeModelChangedListener:(id <ADLModelChangedListener>)listener;

- (void)addCollectionChangedListener:(id <ADLCollectionChangedListener>)listener;
- (void)removeCollectionChangedListener:(id <ADLCollectionChangedListener>)listener;

- (void)addChangeListener:(id <ADLListChangedListener>)listener forList:(ADLListID*)list;
- (void)removeChangeListener:(id <ADLListChangedListener>)listener forList:(ADLListID*)list;

// Mutation
// These all actually modify the calendar store. Be careful. Only call these from outside the abstraction barrier

- (void)setTitle:(NSString*)title ofList:(ADLListID*)listID;
- (void)setShowsCountInBadge:(BOOL)showsCountInBadge forList:(ADLListID*)listID;

- (ADLItemID*)addItemWithTitle:(NSString*)title toListWithID:(ADLListID*)listID;
- (ADLItemID*)addItemWithTitle:(NSString*)title toListWithID:(ADLListID*)listID atIndex:(NSUInteger)index;
- (ADLItemID*)addConcreteItem:(ADLConcreteItem*)concreteItem toListWithID:(ADLListID*)listID atIndex:(NSUInteger)index;

- (void)setCompletionStatus:(BOOL)status ofItem:(NSManagedObjectID *)itemID;
- (void)deleteItemWithID:(ADLItemID*)itemID;
- (void)setTitle:(NSString *)title ofItem:(NSManagedObjectID *)itemID;
// asReorder is YES if we should do this as a rearrange items instead of as an insert/delete
// Drag/Drop wants this to be no so the animations work properly
// Returns the new itemID as it may have changed if asReorder is NO
- (ADLItemID*)moveItem:(ADLItemID*)itemID toIndex:(NSUInteger)index ofList:(ADLListID*)listID asReorder:(BOOL)asReorder;

@end

@protocol ADLModelChangedListener <NSObject>

- (void)modelChanged:(ADLModelAccess*)model;

@end

@protocol ADLCollectionChangedListener <NSObject>

@optional
- (void)changedListsIDsTo:(NSArray *)newOrder;
- (void)changedSelectedListIDTo:(ADLListID*)listID;

@end

@protocol ADLListChangedListener <NSObject>

- (void)list:(ADLListID*)list changedItemIDsTo:(NSArray*)newOrder;

@end

@protocol ADLModelAccessDelegate <NSObject>

- (void)modelDidMutate:(ADLModelAccess*)modelAccess;

@end


extern NSString* kADLItemPasteboardType;