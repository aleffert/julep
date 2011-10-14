//
//  ADLDocumentViewController.m
//  julep
//
//  Created by Akiva Leffert on 10/7/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ADLDocumentViewController.h"

#import "ADLAgnosticDocumentViewController.h"
#import "ADLListViewController.h"
#import "ADLUITabViewController.h"
#import "ADLUIViewManipulator.h"

@interface ADLDocumentViewController ()

@property (retain, nonatomic) ADLAgnosticDocumentViewController* agnostic;
@property (retain, nonatomic) ADLUITabViewController* tabController;
@property (retain, nonatomic) ADLPageScrollViewController* pageController;

- (void)loadViewBody;
- (void)updateActivePagesForSelection:(ADLListID*)listID;

@end

@implementation ADLDocumentViewController

@synthesize agnostic = mAgnostic;
@synthesize tabController = mTabController;
@synthesize pageController = mPageController;

- (void)dealloc {
    self.agnostic = nil;
    [super dealloc];
}

- (void)setModelAccess:(ADLModelAccess *)modelAccess {
    NSAssert(self.agnostic == nil, @"Setting model access when we already have it");
    self.agnostic = [[[ADLAgnosticDocumentViewController alloc] initWithModel:modelAccess] autorelease];
    
    if(self.isViewLoaded) {
        [self loadViewBody];
    }
}

- (ADLModelAccess*)modelAccess {
    return self.agnostic.modelAccess;
}

- (void)loadViewBody {
    if(self.agnostic != nil) {
        ADLUIViewManipulator* viewManipulator = [[[ADLUIViewManipulator alloc] init] autorelease];
        self.tabController = [[[ADLUITabViewController alloc] initWithDataSource:self.agnostic] autorelease];
        self.tabController.viewManipulator = viewManipulator;
        self.agnostic.tabController = self.tabController.agnostic;
        UIView* contentView = self.view;
        CGRect tabFrame = self.tabController.view.frame;
        [contentView addSubview:self.tabController.view];
        
        self.tabController.view.frame = CGRectMake(0, 0, contentView.frame.size.width, tabFrame.size.height);
        
        self.agnostic.tabController.tabInfos = self.agnostic.modelAccess.listIDs;
        
        // Tab Controller gets its actual size programatically
        tabFrame = self.tabController.view.frame;

        self.pageController = [[[ADLPageScrollViewController alloc] init] autorelease];
        self.pageController.delegate = self;
        [contentView addSubview:self.pageController.view];
        self.pageController.view.frame = CGRectMake(0, tabFrame.size.height, contentView.frame.size.width, contentView.frame.size.height - tabFrame.size.height);
        
        self.agnostic.tabController.selectedInfo = self.agnostic.selectedListID;
        self.pageController.pageInfos = self.agnostic.modelAccess.listIDs;
        self.pageController.currentPageInfo = self.agnostic.selectedListID;
        
        [self.agnostic.modelAccess addCollectionChangedListener:self];
    }
}

- (void)viewDidLoad {
    [self loadViewBody];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark Update Views

- (void)updateActivePagesForSelection:(ADLListID*)listID {
    self.pageController.currentPageInfo = listID;
}

#pragma mark Page Scroll View

- (void)pageController:(ADLPageScrollViewController *)pageController changedSelectionTo:(id)info {
    self.agnostic.modelAccess.selectedListID = info;
}

- (UIViewController*)viewControllerForInfo:(id)info pageController:(ADLPageScrollViewController *)pageController {
    ADLListViewController* controller = [[ADLListViewController alloc] init];
    controller.listID = info;
    
    return [controller autorelease];
}

#pragma mark Model Changes

- (void)changedSelectedListIDTo:(ADLListID*)listID {
    [self updateActivePagesForSelection:listID];
}

- (void)changedListsIDsTo:(NSArray *)newOrder {
    [self updateActivePagesForSelection:self.agnostic.selectedListID];
}

@end
