//
//  ADLAgnosticDocumentViewController.m
//  julep
//
//  Created by Akiva Leffert on 10/3/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "ADLAgnosticDocumentViewController.h"
#import "ADLModelAccess.h"

@interface ADLAgnosticDocumentViewController ()

@property (retain, nonatomic) ADLModelAccess* modelAccess;

@end

@implementation ADLAgnosticDocumentViewController

@synthesize modelAccess = mModelAccess;
@synthesize tabController = mTabController;

- (id)initWithModel:(ADLModelAccess*)modelAccess {
    self = [super init];
    if (self) {
        self.modelAccess = modelAccess;
    }
    
    return self;
}

- (void)dealloc {
    self.modelAccess = nil;
    self.tabController = nil;
    
    [super dealloc];
}

- (void)setModelAccess:(ADLModelAccess *)modelAccess {
    [self.modelAccess removeCollectionChangedListener:self];
    [modelAccess retain];
    [mModelAccess release];
    mModelAccess = modelAccess;
    [self.modelAccess addCollectionChangedListener:self];
}

- (NSArray*)listIDs {
    return self.tabController.tabInfos;
}

- (ADLListID*)selectedListID {
    return self.tabController.selectedInfo;
}

- (void)setSelectedListID:(ADLListID*)selectedListID {
    self.tabController.selectedInfo = selectedListID;
}

- (NSUInteger)selectedListIndex {
    return [self.tabController.tabInfos indexOfObject:self.selectedListID];
}

- (ADLListID*)listIDAtIndex:(NSUInteger)index {
    return [self.tabController.tabInfos objectAtIndex:index];
}

- (NSUInteger)indexOfListID:(ADLListID*)listID {
    return [self.tabController.tabInfos indexOfObject:listID];
}

#pragma mark Change Listener

- (void)changedListsIDsTo:(NSArray *)newOrder {
    [self.tabController setTabInfos:newOrder animated:YES];
}

- (void)changedSelectedListIDTo:(ADLListID *)listID {
    self.tabController.selectedInfo = listID;
}

#pragma mark Tab Controller Data Source

- (NSString*)titleOfTab:(id)tab tabController:(ADLTabController*)tabController {
    return [self.modelAccess titleOfList:tab];
}

- (void)changeTitleOfTab:(id)tab to:(NSString *)newTitle tabController:(ADLTabController *)tabController {
    [self.modelAccess setTitle:newTitle ofList:tab];
}

- (void)changeTabInfosTo:(NSArray*)infos tabController:(ADLTabController*)tabController {
    [self.modelAccess setListIDs:infos];
}

- (void)changeSelectedTabTo:(id)tab tabController:(ADLTabController *)tabController {
    [self.modelAccess setSelectedListID:tab];
}

@end
