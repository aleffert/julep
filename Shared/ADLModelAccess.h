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

@protocol ADLCollectionChangedListener;
@protocol ADLListChangedListener;

@interface ADLModelAccess : NSObject

- (ADLModelAccess*)initWithManagedObjectContext:(NSManagedObjectContext*)context;

- (void)populateDefaults;

@property (readonly, nonatomic) NSUInteger listCount;
@property (copy, nonatomic) NSArray* listIDs;
- (NSString*)titleOfList:(ADLListID*)listID;
- (void)addListAtIndex:(NSUInteger)index;
- (void)deleteListWithID:(ADLListID*)listID;

- (void)setTitle:(NSString*)title ofList:(ADLListID*)listID;
- (void)setText:(NSString*)text ofList:(ADLListID*)listID;

- (void)addCollectionChangedListener:(id <ADLCollectionChangedListener>)listener;
- (void)removeCollectionChangedListener:(id <ADLCollectionChangedListener>)listener;

- (void)addListChangedListener:(id <ADLListChangedListener>)listener;
- (void)removeListChangedListener:(id <ADLListChangedListener>)listener;

- (NSString*)bodyTextForListID:(ADLListID*)listID;

@property (retain, nonatomic) ADLListID* selectedListID;

@end


@protocol ADLCollectionChangedListener <NSObject>

@optional
- (void)changedListsIDsTo:(NSArray *)newOrder;
- (void)changedSelectedListIDTo:(ADLListID*)listID;

@end

@protocol ADLListChangedListener <NSObject>

- (void)changedListWithID:(ADLListID *)listID bodyText:(NSString*)bodyText;

@end