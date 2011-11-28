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

- (NSString*)titleOfList:(ADLListID*)listID;

- (BOOL)completionStatusOfItem:(ADLItemID*)itemID;

- (NSString*)titleOfItem:(ADLItemID*)itemID;

- (NSArray*)itemIDsForList:(ADLListID*)listID;

- (void)addCollectionChangedListener:(id <ADLCollectionChangedListener>)listener;
- (void)removeCollectionChangedListener:(id <ADLCollectionChangedListener>)listener;

- (void)addChangeListener:(id <ADLListChangedListener>)listener forList:(ADLListID*)list;
- (void)removeChangeListener:(id <ADLListChangedListener>)listener forList:(ADLListID*)list;


@property (retain, nonatomic) ADLListID* selectedListID;

// Actually modifies the calendar store. Be careful. Only call these from outside
- (void)addItemWithTitle:(NSString*)title toListWithID:(ADLListID*)listID;
- (void)setTitle:(NSString*)title ofList:(ADLListID*)listID;
- (void)setCompletionStatus:(BOOL)status ofItem:(NSManagedObjectID *)itemID;
- (void)deleteItemWithID:(ADLItemID*)itemID;
- (void)setTitle:(NSString *)title ofItem:(NSManagedObjectID *)itemID;

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