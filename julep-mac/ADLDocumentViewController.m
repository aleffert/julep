//
//  ADLDocumentViewController.m
//  julep
//
//  Created by Akiva Leffert on 9/25/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "ADLDocumentViewController.h"

#import "ADLColor.h"
#import "ADLColorView.h"
#import "ADLAgnosticDocumentViewController.h"
#import "ADLListsPileViewController.h"
#import "ADLListViewController.h"
#import "ADLModelAccess.h"
#import "ADLNSTabViewController.h"
#import "ADLNSViewManipulator.h"

@interface ADLDocumentViewController ()

@property (retain, nonatomic) ADLNSTabViewController* tabController;
@property (retain, nonatomic) ADLListsPileViewController* pileController;
@property (retain, nonatomic) ADLAgnosticDocumentViewController* agnostic;

- (void)updateActivePileViewsForSelection:(ADLListID*)currentID;

@end

@implementation ADLDocumentViewController

@synthesize tabController = mTabController;
@synthesize pileController = mPileController;
@synthesize agnostic = mAgnostic;

- (id)initWithModel:(ADLModelAccess*)modelAccess {
    if((self = [super initWithNibName:@"ADLDocumentViewController" bundle:nil])) {
        self.agnostic = [[[ADLAgnosticDocumentViewController alloc] initWithModel:modelAccess] autorelease];

        // make sure we got notified after the agnostic version
        [modelAccess addCollectionChangedListener:self];
    }
    
    return self;
}

- (void)dealloc {
    [self.agnostic.modelAccess removeCollectionChangedListener:self];
    self.agnostic = nil;
    self.tabController = nil;
    self.pileController = nil;
    [super dealloc];
}

- (void)viewDidLoad {
    
    ADLNSViewManipulator* viewManipulator = [[[ADLNSViewManipulator alloc] init] autorelease];
    self.tabController = [[[ADLNSTabViewController alloc] initWithDataSource:self.agnostic] autorelease];
    self.tabController.viewManipulator = viewManipulator;
    self.agnostic.tabController = self.tabController.agnostic;
    NSView* contentView = self.view;
    NSRect tabFrame = self.tabController.view.frame;
    [contentView addSubview:self.tabController.view];

    self.tabController.view.frame = NSMakeRect(0, contentView.frame.size.height - tabFrame.size.height, contentView.frame.size.width, tabFrame.size.height);
    
    self.agnostic.tabController.tabInfos = self.agnostic.modelAccess.listIDs;
    
    // Tab Controller gets its actual size programatically
    tabFrame = self.tabController.view.frame;
    
    self.pileController = [[[ADLListsPileViewController alloc] initWithNibName:@"ADLPileViewController" bundle:nil] autorelease];
    self.pileController.delegate = self;
    [contentView addSubview:self.pileController.view];
    self.pileController.view.frame = CGRectMake(0, 0, contentView.frame.size.width, contentView.frame.size.height - tabFrame.size.height);
    
    self.pileController.nextResponder = self.pileController.view.nextResponder;
    self.pileController.view.nextResponder = self.pileController;
    
    [self updateActivePileViewsForSelection:self.agnostic.selectedListID];
}

- (void)loadView {
    NSView* view = [[NSView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
    view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.view = view;
    [view release];
    [self viewDidLoad];
}

- (void)updateActivePileViewsForSelection:(ADLListID*)currentID {
    ADLListID* currentVisibleID = self.pileController.currentViewController.listID;
    if(![currentVisibleID isEqual:currentID]) {
        ADLListViewController* lvc = [[ADLListViewController alloc] init];
        lvc.listID = currentID;
        self.pileController.currentViewController = lvc;
        [lvc release];
    }
    
    NSUInteger index = [self.agnostic indexOfListID:currentID];
    
    if(index > 0 && index != NSNotFound) {
        NSUInteger prevIndex = index - 1;
        ADLListID* prevVisibleID = self.pileController.prevViewController.listID;
        ADLListID* prevID = [self.agnostic listIDAtIndex:prevIndex];
        if(![prevID isEqual:prevVisibleID]) {
            ADLListViewController* lvc = [[ADLListViewController alloc] init];
            lvc.listID = prevID;
            self.pileController.prevViewController = lvc;
            [lvc release];
        }
    }
    else if(self.pileController.prevViewController != nil) {
        self.pileController.prevViewController = nil;
    }
    
    if(index + 1 < self.agnostic.listIDs.count && index != NSNotFound) {
        NSUInteger nextIndex = index + 1;
        ADLListID* nextVisibleID = self.pileController.nextViewController.listID;
        ADLListID* nextID = [self.agnostic listIDAtIndex:nextIndex];
        if(![nextID isEqual:nextVisibleID]) {
            ADLListViewController* lvc = [[ADLListViewController alloc] init];
            lvc.listID = nextID;
            self.pileController.nextViewController = lvc;
            [lvc release];
        }
    }
    else if(self.pileController.nextViewController != nil) {
        self.pileController.nextViewController = nil;
    }
}

#pragma mark Pile Controller

- (NSViewController*)nextViewControllerAfterActivating:(NSViewController *)newCurrentViewController inPile:(ADLPileViewController *)pileViewController {
    ADLListViewController* newCurrentList = (ADLListViewController*)newCurrentViewController;
    NSInteger index = [self.agnostic indexOfListID:newCurrentList.listID];
    self.agnostic.modelAccess.selectedListID = newCurrentList.listID;
    
    if(index + 1 < self.agnostic.listIDs.count) {
        ADLListViewController* lvc = [[ADLListViewController alloc] init];
        lvc.listID = [self.agnostic listIDAtIndex:index + 1];
        return [lvc autorelease];
    }
    else {
        return nil;
    }
}

- (NSViewController*)prevViewControllerAfterActivating:(NSViewController *)newCurrentViewController inPile:(ADLPileViewController *)pileViewController {
    ADLListViewController* newCurrentList = (ADLListViewController*)newCurrentViewController;
    NSInteger index = [self.agnostic indexOfListID:newCurrentList.listID];
    self.agnostic.modelAccess.selectedListID = newCurrentList.listID;
    
    if(index > 0) {
        ADLListViewController* lvc = [[ADLListViewController alloc] init];
        lvc.listID = [self.agnostic listIDAtIndex:index - 1];
        return [lvc autorelease];
    }
    else {
        return nil;
    }
}

- (NSView*)backgroundViewForPile:(ADLPileViewController *)pileController {
    
    ADLColorView* backgroundView = [[ADLColorView alloc] initWithFrame:pileController.view.bounds];
    backgroundView.backgroundColor = [ADLColor scrollViewBackgroundColor].CGColor;
    backgroundView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    
    return [backgroundView autorelease];
}

#pragma mark Model Changes

- (void)changedSelectedListIDTo:(ADLListID*)listID {
    [self updateActivePileViewsForSelection:listID];
}

- (void)changedListsIDsTo:(NSArray *)newOrder {
    [self updateActivePileViewsForSelection:self.agnostic.selectedListID];
}

#pragma mark Menus

- (IBAction)newList:(id)sender {
    NSUInteger currentIndex = self.agnostic.selectedListIndex;
    NSUInteger newIndex = currentIndex == NSNotFound ? 0 : currentIndex + 1;
    [self.agnostic.modelAccess addListAtIndex:newIndex];
    self.agnostic.modelAccess.selectedListID = [self.agnostic listIDAtIndex:newIndex];
}

- (IBAction)deleteFrontList:(id)sender {
    [self.agnostic.modelAccess deleteListWithID:self.agnostic.selectedListID];
}

- (IBAction)previousList:(id)sender {
    NSUInteger index = self.agnostic.selectedListIndex;
    NSAssert(index > 0, @"Moving previous without extant previous list");
    self.agnostic.modelAccess.selectedListID = [self.agnostic listIDAtIndex:index - 1];
}

- (IBAction)nextList:(id)sender {
    NSUInteger index = self.agnostic.selectedListIndex;
    NSAssert(index + 1 < self.agnostic.listIDs.count, @"Moving next without extant next list");
    self.agnostic.modelAccess.selectedListID = [self.agnostic listIDAtIndex:index + 1];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if(menuItem.action == @selector(previousList:)) {
        return self.pileController.prevViewController != nil;
    }
    else if(menuItem.action == @selector(nextList:)) {
        return self.pileController.nextViewController != nil;
    }
    else if(menuItem.action == @selector(deleteFrontList:)) {
        return self.agnostic.listIDs.count > 1;
    }
    else {
        return YES;
    }
}

@end
