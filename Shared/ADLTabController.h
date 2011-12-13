//
//  ADLTabController.h
//  julep
//
//  Created by Akiva Leffert on 8/22/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ADLTabView.h"

@protocol ADLScrollView;
@protocol ADLTabView;
@protocol ADLView;
@protocol ADLViewManipulator;

@protocol ADLTabControllerDelegate;
@protocol ADLTabControllerDataSource;

@interface ADLTabController : NSObject <ADLTabViewDelegate> {
    id <ADLTabView> mCurrentlyDraggingTab;
    NSMutableArray* mReorderedTabs;
    id <ADLTabView> mSelectedTab;
    id <ADLTabControllerDataSource> mDataSource;
    id <ADLTabControllerDelegate> mDelegate;
    NSArray* mTabs;
    NSArray* mTabInfos;
    id mSelectedInfo;
}

- (id)initWithDelegate:(id <ADLTabControllerDelegate>)newDelegate dataSource:(id <ADLTabControllerDataSource>)newDataSource;

@property (nonatomic, readonly) id <ADLTabControllerDelegate> delegate;
@property (nonatomic, readonly) id <ADLTabControllerDataSource> dataSource;

@property (nonatomic, retain) id selectedInfo;
@property (nonatomic, assign) NSUInteger selectedIndex;

@property (nonatomic, copy) NSArray* tabInfos; // id array
- (void)setTabInfos:(NSArray *)tabInfos animated:(BOOL)animated;

@end


@protocol ADLTabControllerDelegate <NSObject>

@property (retain, readonly, nonatomic) id <ADLView> bodyView;
@property (retain, readonly, nonatomic) id <ADLScrollView> scrollView;
@property (retain, readonly, nonatomic) id <ADLViewManipulator> viewManipulator;

- (id <ADLTabView>)makeTabViewForTabController:(ADLTabController*)tabController;
- (void)updateSizeForContentWidth:(CGFloat)width;
- (void)animateInTabView:(id <ADLTabView>)tabView;
- (void)animateOutTabView:(id <ADLTabView>)tabView;
- (void)makeTabVisible:(id <ADLTabView>)tabView;

@end

@protocol ADLTabControllerDataSource <NSObject>

- (NSString*)titleOfTab:(id)tab tabController:(ADLTabController*)tabController;
- (void)changeTitleOfTab:(id)tab to:(NSString*)newTitle tabController:(ADLTabController*)tabController;
- (void)changeTabInfosTo:(NSArray*)infos tabController:(ADLTabController*)tabController;
- (void)changeSelectedTabTo:(id)tab tabController:(ADLTabController*)tabController;

@end