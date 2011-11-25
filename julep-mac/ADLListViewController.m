//
//  ADLListViewController.m
//  julep
//
//  Created by Akiva Leffert on 9/19/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ADLListViewController.h"

#import "ADLItemView.h"

@interface ADLListViewController ()

@property (retain, nonatomic) NSTableView* tableView;

@end

@implementation ADLListViewController

@synthesize listID = mListID;
@synthesize delegate = mDelegate;
@synthesize modelAccess = mModelAccess;
@synthesize tableView = mTableView;
@synthesize items = mItems;

- (id)init {
    if((self = [super initWithNibName:@"ADLListViewController" bundle:nil])) {
    }
    
    return self;
}

- (void)dealloc {
    [self.delegate listViewControllerWillDealloc:self];
    [super dealloc];
}

- (void)viewDidLoad {
    self.view.wantsLayer = YES;
    
    NSScrollView *scrollview = [[NSScrollView alloc] initWithFrame:self.view.bounds];
    scrollview.wantsLayer = YES;
    
    scrollview.borderType = NSNoBorder;
    scrollview.hasVerticalScroller = YES;
    scrollview.hasHorizontalScroller = NO;
    scrollview.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    scrollview.verticalScrollElasticity = NSScrollElasticityAllowed;
    
    [self.view addSubview:scrollview];
    
    NSTableView* tableView = [[NSTableView alloc] initWithFrame:self.view.bounds];
    tableView.delegate = self;
    tableView.dataSource = self;
    tableView.headerView = nil;
    tableView.allowsMultipleSelection = YES;
    
    NSTableColumn* column = [[NSTableColumn alloc] initWithIdentifier:@"main column"];
    column.resizingMask = NSTableColumnAutoresizingMask;
    column.width = self.view.frame.size.width;
    [tableView addTableColumn:column];
    
    [scrollview setDocumentView:tableView];
    self.tableView = tableView;
    
    [column release];
    [tableView release];
    [scrollview release];
}

- (void)loadView {
    [super loadView];
    [self viewDidLoad];
}

- (void)didActivate {
    self.view.nextResponder = self;
    [self.view.window makeFirstResponder:self.tableView];
}

- (void)list:(ADLListID *)list changedItemIDsTo:(NSArray *)newOrder {
    NSMutableIndexSet* addingItems = [NSMutableIndexSet indexSet];
    NSMutableIndexSet* deletingItems = [NSMutableIndexSet indexSet];
    
    [self.tableView beginUpdates];
    for(ADLItemID* itemID in newOrder) {
        NSUInteger index = [self.items indexOfObject:itemID];
        NSUInteger newIndex = [newOrder indexOfObject:itemID];
        if(index == NSNotFound) {
            [addingItems addIndex:newIndex];
        }
    }
    
    for(ADLItemID* itemID in self.items) {
        NSUInteger index = [self.items indexOfObject:itemID];
        NSUInteger newIndex = [newOrder indexOfObject:itemID];
        if(newIndex == NSNotFound) {
            [deletingItems addIndex:index];
        }
    }
    
    self.items = newOrder;
    
    [self.tableView removeRowsAtIndexes:deletingItems withAnimation:NSTableViewAnimationSlideLeft | NSTableViewAnimationEffectGap];
    [self.tableView insertRowsAtIndexes:addingItems withAnimation:NSTableViewAnimationSlideRight | NSTableViewAnimationEffectGap];
    
    // Do the move after insert/remove so the post indices are correct
    for(ADLItemID* itemID in newOrder) {
        NSUInteger index = [self.items indexOfObject:itemID];
        NSUInteger newIndex = [newOrder indexOfObject:itemID];
        if(index != NSNotFound && index != newIndex) {
            [self.tableView moveRowAtIndex:index toIndex:newIndex];
        }
    }
    
    [self.tableView endUpdates];
    
    [self.tableView enumerateAvailableRowViewsUsingBlock:^(NSTableRowView* rowView, NSInteger rowIndex) {
        ADLItemView* itemView = [rowView viewAtColumn:0];
        NSAssert([newOrder containsObject:itemView.item], @"Updating item not in new list");
        itemView.title = [self.modelAccess titleOfItem:itemView.item];
        itemView.checked = [self.modelAccess completionStatusOfItem:itemView.item];
    }];
}

#pragma mark Data Source

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.items.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    ADLItemID* item = [self.items objectAtIndex:row];
    ADLItemView* itemView = [[ADLItemView alloc] initWithFrame:NSMakeRect(0, 0, tableView.bounds.size.width, 90)];
    
    itemView.item = item;
    itemView.title = [self.modelAccess titleOfItem:item];
    itemView.checked = [self.modelAccess completionStatusOfItem:item];
    itemView.delegate = self;
    
    return itemView;
}

#pragma mark Item View Delegate

- (void)itemView:(ADLItemView *)itemView changedTitle:(NSString *)item {
    [self.modelAccess setTitle:item ofItem:itemView.item];
}

- (void)itemView:(ADLItemView *)itemView changedCompletionStatus:(BOOL)status {
    [self.modelAccess setCompletionStatus:status ofItem:itemView.item];
}

- (void)keyDown:(NSEvent *)theEvent {
    [self interpretKeyEvents:[NSArray arrayWithObject:theEvent]];
}

- (void)deleteBackward:(id)sender {
    NSIndexSet* selection = self.tableView.selectedRowIndexes;
    NSMutableArray* items = [NSMutableArray array];
    [selection enumerateIndexesUsingBlock: ^(NSUInteger index, BOOL* stop) {
        [items addObject:[self.items objectAtIndex:index]];
    }];
    for (ADLItemID* item in items) {
        [self.modelAccess deleteItemWithID:item];
    }
}


@end
