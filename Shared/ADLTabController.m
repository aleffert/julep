//
//  ADLTabController.m
//  julep
//
//  Created by Akiva Leffert on 8/22/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ADLTabController.h"

#import "NSArray+ADLAdditions.h"
#import "ADLScrollView.h"
#import "ADLTabView.h"
#import "ADLViewManipulator.h"

@interface ADLTabController ()

@property (assign, nonatomic) id <ADLTabControllerDelegate> delegate;
@property (assign, nonatomic) id <ADLTabControllerDataSource> dataSource;
@property (retain, nonatomic) NSArray* tabs;

@property (retain, nonatomic) NSMutableArray* reorderedTabs;
@property (retain, nonatomic) id <ADLTabView> currentlyDraggingTab;
@property (readonly, nonatomic) id <ADLTabView> selectedTab;

- (id)infoForTabView:(id <ADLTabView>)tabView;

- (void)layoutSubviewsNotAnimating:(NSArray*)immediateTabs;

- (void)layoutSubviews;

@end

@implementation ADLTabController

@synthesize currentlyDraggingTab = mCurrentlyDraggingTab;
@synthesize dataSource = mDataSource;
@synthesize delegate = mDelegate;
@synthesize reorderedTabs = mReorderedTabs;
@synthesize tabs = mTabs;
@synthesize tabInfos = mTabInfos;
@synthesize selectedInfo = mSelectedInfo;

- (id)initWithDelegate:(id <ADLTabControllerDelegate>)newDelegate dataSource:(id <ADLTabControllerDataSource>)newDataSource {
    self = [super init];
    if(self) {
        self.delegate = newDelegate;
        self.dataSource = newDataSource;
        self.tabs = [NSArray array];
        self.tabInfos = [NSArray array];
    }
    return self;
}

- (void)dealloc {
    self.tabs = nil;
    [super dealloc];
}

- (void)setSelectedIndex:(NSUInteger)selectedIndex {
    [self setSelectedInfo:[self.tabInfos objectAtIndex:selectedIndex]];
 }

- (NSUInteger)selectedIndex {
    return [self.tabInfos indexOfObject:self.selectedInfo];
}

- (void)setSelectedInfo:(id)selectedInfo {
    if(selectedInfo != mSelectedInfo) {
        NSUInteger selectedIndex = [self.tabInfos indexOfObject:selectedInfo];
        id <ADLTabView> tab = [self.tabs objectAtIndex:selectedIndex];
        
        id <ADLTabView> selectedTab = self.selectedTab;
        selectedTab.selected = NO;
        tab.selected = YES;
        [self.delegate.viewManipulator orderViewFront:tab];
    }
    [selectedInfo retain];
    [mSelectedInfo release];
    mSelectedInfo = selectedInfo;
}

//- (void)reload {
//    [self clear];
//    
//    NSUInteger tabCount = self.tabInfos.count;
//    id <ADLView> bodyView = self.delegate.bodyView;
//    id <ADLViewManipulator> viewManipulator = self.delegate.viewManipulator;
//    for(NSUInteger tabIndex = 0; tabIndex < tabCount; tabIndex++) {
//        id tab = [self.tabInfos objectAtIndex:tabIndex];
//        id <ADLTabView> tabView = [self.delegate makeTabViewForTabController:self];
//        tabView.delegate = self;
//        [self.tabs addObject:tabView];
//        [viewManipulator addSubview:tabView toView:bodyView];
//    }
//    
//    if(self.tabInfos.count > 0 && self.selectedInfo == nil) {
//        self.selectedInfo = [self.tabInfos objectAtIndex:0];
//    }
//    
//    [self layoutSubviews];
//}


- (void)setTabInfos:(NSArray *)tabInfos animated:(BOOL)animated {
    [CATransaction begin];
    [CATransaction setAnimationDuration:0];
    NSMutableArray* addingTabs = [NSMutableArray array];
    NSMutableArray* deletingTabs = [NSMutableArray arrayWithArray:self.tabs];
    id <ADLViewManipulator> viewManipulator = self.delegate.viewManipulator;
    __block ADLTabController* owner = self;
    
    NSArray* newTabs = [tabInfos arrayByMappingObjects:^(id tabInfo) {
        NSUInteger index = [owner.tabInfos indexOfObject:tabInfo];
        __block id <ADLTabView> tabView = nil;
        if(index == NSNotFound) {
            tabView = [owner.delegate makeTabViewForTabController:owner];
            tabView.delegate = owner;
            [viewManipulator addSubview:tabView toView:owner.delegate.bodyView];
            [addingTabs addObject:tabView];
        }
        else {
            tabView = [owner.tabs objectAtIndex:index];
            // Exists again so don't delete it
            [deletingTabs removeObject:tabView];
        }
        // Update the title in case it changed
        tabView.title = [owner.dataSource titleOfTab:tabInfo tabController:owner];
        return tabView;
    }];
    
    [mTabInfos release];
    mTabInfos = [tabInfos copy];
    
    self.tabs = newTabs;
        
    [viewManipulator performAnimations:^(void) {
        [self layoutSubviewsNotAnimating:addingTabs];
    } duration:animated ? .2 : 0];
        
        for(id <ADLTabView> addingTab in addingTabs) {
            [self.delegate animateInTabView:addingTab];
        }
        
        for(id <ADLTabView> deletingTab in deletingTabs) {
            [self.delegate animateOutTabView:deletingTab];
        }
    
    
    if(self.tabInfos.count > 0 && (self.selectedInfo == nil || ![self.tabInfos containsObject:self.selectedInfo])) {
        self.selectedInfo = [self.tabInfos objectAtIndex:0];
    }
    
    [CATransaction commit];
}

- (void)setTabInfos:(NSArray *)tabInfos {
    [self setTabInfos:tabInfos animated:NO];
}

- (id <ADLTabView>)selectedTab {
    id <ADLTabView> selectedTab = nil;
    for(id <ADLTabView> currentTab in self.tabs) {
        if(currentTab.selected) {
            selectedTab = currentTab;
        }
    }
    return selectedTab;
}

- (void)layoutSubviewsNotAnimating:(NSArray*)immediateTabs {
    CGFloat accumulatedWidth = 0;
    id <ADLViewManipulator> viewManipulator = self.delegate.viewManipulator;
    NSArray* tabs = self.currentlyDraggingTab != nil ? self.reorderedTabs : self.tabs;
    for(id <ADLTabView> tabView in tabs) {
        CGRect frame = [viewManipulator frameOfView:tabView];
        if(tabView != self.currentlyDraggingTab) {
            frame.origin.x = accumulatedWidth;
            if([immediateTabs containsObject:tabView]) {
                [viewManipulator performAnimations:^(void) {
                    [viewManipulator setFrame:frame ofView:tabView];
                } duration:0];
            }
            else {
                [viewManipulator setFrame:frame ofView:tabView];
            }
        }
        [viewManipulator orderViewFront:tabView];
        accumulatedWidth += frame.size.width - 15;
    }
    if(self.currentlyDraggingTab == nil) {
        [viewManipulator orderViewFront:self.selectedTab];
    }
    else {
        [viewManipulator orderViewFront:self.currentlyDraggingTab];
    }
    
    [self.delegate updateSizeForContentWidth:accumulatedWidth + 15];
}

- (void)layoutSubviews {
    [self layoutSubviewsNotAnimating:[NSArray array]];
}

- (id)infoForTabView:(id <ADLTabView>)tabView {
    return [self.tabInfos objectAtIndex:[self.tabs indexOfObject:tabView]];
}

#pragma mark <ADLTabViewDelegate>

- (void)shouldChangeTitleOfTab:(id<ADLTabView>)tabView to:(NSString *)newTitle {
    id tabInfo = [self infoForTabView:tabView];
    [self.dataSource changeTitleOfTab:tabInfo to:newTitle tabController:self];
}

- (void)shouldSelectTab:(id<ADLTabView>)tab {
    [self.dataSource changeSelectedTabTo:[self infoForTabView:tab] tabController:self];
}

- (void)beginDraggingTab:(id <ADLTabView>)tab {
    [self.delegate.viewManipulator orderViewFront:tab];
    self.currentlyDraggingTab = tab;
    self.reorderedTabs = [[self.tabs mutableCopy] autorelease];
}

- (void)draggedTab:(id <ADLTabView>)tab toParentLocation:(CGFloat)xLocation withDelta:(CGFloat)delta {
    NSAssert(tab == self.currentlyDraggingTab, @"Dragging unexpected tab");
    id <ADLViewManipulator> viewManipulator = self.delegate.viewManipulator;
    CGRect frame = [viewManipulator frameOfView:tab];
    frame.origin.x = frame.origin.x + delta;
    [viewManipulator setFrame:frame ofView:tab];
    
    NSMutableArray* newTabOrder = nil;
    
    for(id <ADLTabView> currentTab in self.reorderedTabs) {
        CGRect currentFrame = [viewManipulator frameOfView:currentTab];
        currentFrame = CGRectInset(currentFrame, 15, 0);
        if(currentTab != tab && CGRectContainsPoint(currentFrame, CGPointMake(xLocation, CGRectGetMidY(currentFrame)))) {
            newTabOrder = [[self.reorderedTabs mutableCopy] autorelease];
            [newTabOrder removeObject:currentTab];

            if(currentFrame.origin. x < frame.origin.x) {
                // Move after
                [newTabOrder insertObject:currentTab atIndex:[newTabOrder indexOfObject:tab] + 1];
            }
            else {
                // Move in front
                [newTabOrder insertObject:currentTab atIndex:[newTabOrder indexOfObject:tab]];
            }
            break;
        }
    }
    if(newTabOrder != nil) {
        self.reorderedTabs = newTabOrder;
        [viewManipulator performAnimations:^{
            [self layoutSubviews];
        } duration:.2];
    }
}

- (void)endDraggingTab:(id <ADLTabView>)tab {
    NSMutableArray* newInfoOrder = [NSMutableArray array];
    for(id <ADLTabView> tabView in self.reorderedTabs) {
        [newInfoOrder addObject:[self infoForTabView:tabView]];
    }
    
    self.reorderedTabs = nil;
    self.currentlyDraggingTab = nil;
    
    [self.dataSource changeTabInfosTo:newInfoOrder tabController:self];
    [self shouldSelectTab:tab];
}

- (void)cancelDraggingTab:(id <ADLTabView>)tab {
    self.reorderedTabs = nil;
    self.currentlyDraggingTab = nil;
    [self.delegate.viewManipulator performAnimations:^(void) {
        [self layoutSubviews];
    } duration:.2];
}

@end
