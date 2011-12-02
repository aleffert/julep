//
//  ADLListViewController.m
//  julep
//
//  Created by Akiva Leffert on 9/19/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ADLListViewController.h"

#import "ADLConcreteItem.h"
#import "ADLItemDragRecord.h"
#import "ADLItemView.h"
#import "NSArray+ADLAdditions.h"

@interface ADLListViewController ()

@property (retain, nonatomic) NSTableView* tableView;
@property (assign, nonatomic) BOOL dragItemsConsecutive;
@property (assign, nonatomic) NSUInteger dragStartingRow;

@end

@implementation ADLListViewController

@synthesize listID = mListID;
@synthesize delegate = mDelegate;
@synthesize modelAccess = mModelAccess;
@synthesize tableView = mTableView;
@synthesize items = mItems;
@synthesize dragStartingRow = mDragStartingRow;
@synthesize dragItemsConsecutive = mDragItemsConsecutive;

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
    [tableView setDraggingSourceOperationMask:NSDragOperationMove | NSDragOperationDelete forLocal:YES];
    [tableView registerForDraggedTypes:[NSArray arrayWithObject:kADLItemDragRecordPasteboardType]];
    
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
    NSIndexSet* currentSelection = self.tableView.selectedRowIndexes;
    NSIndexSet* newSelection = [newOrder indexesOfObjectsPassingTest:^(id object, NSUInteger index, BOOL* stop) {
        BOOL result = [currentSelection containsIndex:[self.items indexOfObject:object]] && [newOrder containsObject:object];
        return result;
    }];
    
    self.items = newOrder;
    
    [self.tableView reloadData];
    [self.view.window makeFirstResponder:self.tableView];
    
    [self.tableView selectRowIndexes:newSelection byExtendingSelection:NO];
    
//    NSMutableIndexSet* addingItems = [NSMutableIndexSet indexSet];
//    NSMutableIndexSet* deletingItems = [NSMutableIndexSet indexSet];
//    
//    [self.tableView beginUpdates];
//    for(ADLItemID* itemID in newOrder) {
//        NSUInteger index = [self.items indexOfObject:itemID];
//        NSUInteger newIndex = [newOrder indexOfObject:itemID];
//        if(index == NSNotFound) {
//            [addingItems addIndex:newIndex];
//        }
//    }
//    
//    for(ADLItemID* itemID in self.items) {
//        NSUInteger index = [self.items indexOfObject:itemID];
//        NSUInteger newIndex = [newOrder indexOfObject:itemID];
//        if(newIndex == NSNotFound) {
//            [deletingItems addIndex:index];
//        }
//    }
//    
//    [self.tableView removeRowsAtIndexes:deletingItems withAnimation:NSTableViewAnimationSlideLeft | NSTableViewAnimationEffectGap];
//    [self.tableView insertRowsAtIndexes:addingItems withAnimation:NSTableViewAnimationSlideRight | NSTableViewAnimationEffectGap];
//    
//    // Do the move after insert/remove so the post indices are correct
//    for(ADLItemID* itemID in newOrder) {
//        NSUInteger index = [self.items indexOfObject:itemID];
//        NSUInteger newIndex = [newOrder indexOfObject:itemID];
//        if(index != NSNotFound && index != newIndex) {
//            [self.tableView moveRowAtIndex:index toIndex:newIndex];
//            NSLog(@"moved %lu to %lu", index, newIndex);
//        }
//        NSLog(@"see now item as %@", [self.modelAccess titleOfItem:itemID]);
//    }
//    
//    
//    self.items = newOrder;
//    
//    [self.tableView endUpdates];
//    
////    [self.tableView enumerateAvailableRowViewsUsingBlock:^(NSTableRowView* rowView, NSInteger rowIndex) {
////        ADLItemView* itemView = [rowView viewAtColumn:0];
////        NSAssert([newOrder containsObject:itemView.item], @"Updating item not in new list");
////        itemView.title = [self.modelAccess titleOfItem:itemView.item];
////        itemView.checked = [self.modelAccess completionStatusOfItem:itemView.item];
////    }];
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

- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id<NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)dropOperation {
    if((self.dragStartingRow == row || self.dragStartingRow + 1 == row) && self.dragItemsConsecutive) {
        // If we're not doing anything, skip so we don't end up with extra junk on the undo stack
        return NSDragOperationNone;
    }
    return dropOperation == NSTableViewDropAbove ? (NSDragOperationMove | NSDragOperationDelete) : NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id<NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation {
    NSArray* objects = [[info draggingPasteboard] readObjectsForClasses:[NSArray arrayWithObject:[ADLItemDragRecord class]] options:nil];
    ADLItemID* previousItem = nil;
    for(ADLItemDragRecord* record in objects) {
        NSUInteger index = row;
        if(previousItem != nil) {
            index = [self.modelAccess indexOfItem:previousItem inList:self.listID] + 1;
        }
        ADLItemID* itemID = [self.modelAccess itemIDForURL:record.itemURL];
        previousItem = [self.modelAccess moveItem:itemID toIndex:index ofList:self.listID asReorder:NO];
    }
        
    return YES;
}

- (void)tableView:(NSTableView *)tableView draggingSession:(NSDraggingSession *)session willBeginAtPoint:(NSPoint)screenPoint forRowIndexes:(NSIndexSet *)rowIndexes {
    self.dragStartingRow = rowIndexes.firstIndex;
    self.dragItemsConsecutive = (rowIndexes.lastIndex - rowIndexes.firstIndex) == rowIndexes.count - 1;
}

- (id <NSPasteboardWriting>)tableView:(NSTableView *)tableView pasteboardWriterForRow:(NSInteger)row {
    ADLItemID* itemID = [self.items objectAtIndex:row];
    return [ADLItemDragRecord dragRecordWithItemID:itemID];
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

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if(menuItem.action == @selector(cut:) || menuItem.action == @selector(copy:)) {
        return self.tableView.selectedRowIndexes.count > 0;
    }
    else if(menuItem.action == @selector(paste:)) {
        NSPasteboard* pasteboard = [NSPasteboard generalPasteboard];
        return [pasteboard canReadItemWithDataConformingToTypes:[NSArray arrayWithObject:kADLItemPasteboardType]];
    }
    else {
        return [super validateMenuItem:menuItem];
    }
}

#pragma mark Pasteboard

- (void)copyIndices:(NSIndexSet*)indices {
    NSPasteboard* pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];
    NSArray* copiedItems = [self.items objectsAtIndexes:indices];
    NSArray* copiedObjects = [copiedItems arrayByMappingObjects:^(id object) {
        ADLItemID* itemID = object;
        return [self.modelAccess pasteboardRepresentationOfItemID:itemID];
    }];
    [pasteboard writeObjects:copiedObjects];
}

- (void)deleteIndices:(NSIndexSet*)indices {
    NSArray* deletingItemIDs = [self.items objectsAtIndexes:indices];
    for(ADLItemID* itemID in deletingItemIDs) {
        [self.modelAccess deleteItemWithID:itemID];
    }
}

- (void)pasteStartingAt:(NSUInteger)index {
    NSArray* objects = [[NSPasteboard generalPasteboard] readObjectsForClasses:[NSArray arrayWithObject:[ADLConcreteItem class]] options:nil];
    for(ADLConcreteItem* item in objects) {
        ADLItemID* itemID = [self.modelAccess addItemWithTitle:item.title toListWithID:self.listID atIndex:index];
        [self.modelAccess setCompletionStatus:item.completionStatus ofItem:itemID];
        index++;
    }
}

- (void)cut:(id)sender {
    NSIndexSet* selection = self.tableView.selectedRowIndexes;
    [self copyIndices:selection];
    [self deleteIndices:selection];
}

- (void)copy:(id)sender {
    [self copyIndices:self.tableView.selectedRowIndexes];
}

- (void)paste:(id)sender {
    NSUInteger startIndex = [self.tableView.selectedRowIndexes lastIndex];
    startIndex = startIndex == NSNotFound ? 0 : (startIndex + 1);
    [self pasteStartingAt:startIndex];
}

@end
