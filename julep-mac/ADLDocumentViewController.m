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
#import "ADLShadowView.h"

#import "NSArray+ADLAdditions.h"
#import "NSShadow+ADLExtensions.h"

@interface ADLDocumentViewController ()

@property (retain, nonatomic) ADLNSTabViewController* tabController;
@property (retain, nonatomic) ADLListsPileViewController* pileController;
@property (retain, nonatomic) ADLAgnosticDocumentViewController* agnostic;

- (void)updateActivePileViewsForSelection:(ADLListID*)currentID;
- (ADLListViewController*)listViewControllerWithID:(ADLListID*)listID;

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
    [contentView addSubview:self.pileController.view positioned:NSWindowBelow relativeTo:self.tabController.view];
    self.pileController.view.frame = NSMakeRect(0, 0, contentView.frame.size.width, contentView.frame.size.height - tabFrame.size.height);
    
    self.pileController.nextResponder = self.pileController.view.nextResponder;
    self.pileController.view.nextResponder = self.pileController;
    
    self.agnostic.tabController.selectedInfo = self.agnostic.modelAccess.selectedListID;
    
    NSRect shadowFrame = NSInsetRect(self.tabController.view.frame, 0, -5);
    ADLShadowView* tabShadow = [[ADLShadowView alloc] initWithFrame:shadowFrame];
    tabShadow.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    tabShadow.shadow = [NSShadow standardShadow];
    tabShadow.insets = NSEdgeInsetsMake(5, 0, 5, 0);
    [self.view addSubview:tabShadow positioned:NSWindowBelow relativeTo:self.tabController.view];
    [tabShadow release];
    
    [self updateActivePileViewsForSelection:self.agnostic.selectedListID];
}

- (void)loadView {
    NSView* view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 400, 400)];
    view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.view = view;
    [view release];
    [self viewDidLoad];
}

- (void)wasAddedToWindow {
    [self.pileController.currentViewController didActivate];
}

#pragma mark List View Controllers

- (void)listViewControllerWillDealloc:(ADLListViewController *)controller {
    [self.agnostic.modelAccess removeChangeListener:controller forList:controller.listID];
}


- (ADLListViewController*)listViewControllerWithID:(ADLListID*)listID {
    ADLListViewController* lvc = [[ADLListViewController alloc] init];
    lvc.delegate = self;
    lvc.listID = listID;
    lvc.modelAccess = self.agnostic.modelAccess;
    lvc.items = [self.agnostic.modelAccess itemIDsForList:listID];
    [self.agnostic.modelAccess addChangeListener:lvc forList:listID];
    return [lvc autorelease];
}

- (void)updateActivePileViewsForSelection:(ADLListID*)currentID {
    ADLListID* currentVisibleID = self.pileController.currentViewController.listID;
    if(![currentVisibleID isEqual:currentID]) {
        ADLListViewController* lvc = [self listViewControllerWithID:currentID];
        self.pileController.currentViewController = lvc;
        lvc.nextResponder = self.pileController.view;
        [lvc didActivate];
    }
    
    NSUInteger index = [self.agnostic indexOfListID:currentID];
    
    if(index > 0 && index != NSNotFound) {
        NSUInteger prevIndex = index - 1;
        ADLListID* prevVisibleID = self.pileController.prevViewController.listID;
        ADLListID* prevID = [self.agnostic listIDAtIndex:prevIndex];
        if(![prevID isEqual:prevVisibleID]) {
            ADLListViewController* lvc = [self listViewControllerWithID:prevID];
            self.pileController.prevViewController = lvc;
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
            ADLListViewController* lvc = [self listViewControllerWithID:nextID];
            self.pileController.nextViewController = lvc;
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
    
    [newCurrentList didActivate];
    
    if(index + 1 < self.agnostic.listIDs.count) {
        ADLListID* listID = [self.agnostic listIDAtIndex:index + 1];
        ADLListViewController* lvc = [self listViewControllerWithID:listID];
        return lvc;
    }
    else {
        return nil;
    }
}

- (NSViewController*)prevViewControllerAfterActivating:(NSViewController *)newCurrentViewController inPile:(ADLPileViewController *)pileViewController {
    ADLListViewController* newCurrentList = (ADLListViewController*)newCurrentViewController;
    NSInteger index = [self.agnostic indexOfListID:newCurrentList.listID];
    self.agnostic.modelAccess.selectedListID = newCurrentList.listID;
    
    [newCurrentList didActivate];
    
    if(index > 0) {
        ADLListID* listID = [self.agnostic listIDAtIndex:index - 1];
        ADLListViewController* lvc = [self listViewControllerWithID:listID];
        return lvc;
    }
    else {
        return nil;
    }
}

- (NSView*)backgroundViewForPile:(ADLPileViewController *)pileController {
    
    ADLColorView* backgroundView = [[ADLColorView alloc] initWithFrame:pileController.view.bounds];
    backgroundView.backgroundColor = [NSColor colorWithPatternImage:[NSImage imageNamed:@"ADLLinen"]];
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

- (IBAction)previousList:(id)sender {
    NSUInteger index = self.agnostic.selectedListIndex;
    if(index > 0) {
        self.agnostic.modelAccess.selectedListID = [self.agnostic listIDAtIndex:index - 1];
    }
    else {
        self.agnostic.modelAccess.selectedListID = [self.agnostic listIDAtIndex:self.agnostic.listIDs.count - 1];
    }
}

- (IBAction)nextList:(id)sender {
    NSUInteger index = self.agnostic.selectedListIndex;
    if(index + 1 < self.agnostic.listIDs.count) {
        self.agnostic.modelAccess.selectedListID = [self.agnostic listIDAtIndex:index + 1];
    }
    else {
        self.agnostic.modelAccess.selectedListID = [self.agnostic listIDAtIndex:0];
    }
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if(menuItem.action == @selector(previousList:)) {
        return YES;
    }
    else if(menuItem.action == @selector(nextList:)) {
        return YES;
    }
    else if(menuItem.action == @selector(deleteFrontList:)) {
        return self.agnostic.listIDs.count > 1;
    }
    else {
        return YES;
    }
}


@end
