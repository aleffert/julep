//
//  ADLAgnosticDocumentViewController.h
//  julep
//
//  Created by Akiva Leffert on 10/3/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ADLModelAccess.h"
#import "ADLTabController.h"

@interface ADLAgnosticDocumentViewController : NSObject <ADLTabControllerDataSource, ADLCollectionChangedListener> {
    ADLModelAccess* mModelAccess;
    ADLTabController* mTabController;
}

- (id)initWithModel:(ADLModelAccess*)modelAccess;

@property (readonly, retain, nonatomic) ADLModelAccess* modelAccess;
@property (retain, nonatomic) ADLTabController* tabController;

@property (readonly, nonatomic) NSArray* listIDs;
@property (retain, nonatomic) ADLListID* selectedListID;
@property (readonly, nonatomic) NSUInteger selectedListIndex;
- (ADLListID*)listIDAtIndex:(NSUInteger)index;
- (NSUInteger)indexOfListID:(ADLListID*)listID;

@end
