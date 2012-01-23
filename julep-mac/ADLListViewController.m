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
#import "ADLNSScrollView.h"
#import "NSArray+ADLAdditions.h"

@interface ADLListViewController ()

@property (retain, nonatomic) NSTableView* tableView;
@property (assign, nonatomic) BOOL dragItemsConsecutive;
@property (assign, nonatomic) NSUInteger dragStartingRow;
@property (retain, nonatomic) ADLItemView* editingView;

@end

@implementation ADLListViewController

@synthesize listID = mListID;
@synthesize delegate = mDelegate;
@synthesize modelAccess = mModelAccess;
@synthesize tableView = mTableView;
@synthesize items = mItems;
@synthesize dragStartingRow = mDragStartingRow;
@synthesize dragItemsConsecutive = mDragItemsConsecutive;
@synthesize editingView = mEditingView;

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
    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:self.view.bounds];
    
    scrollView.borderType = NSNoBorder;
    scrollView.hasVerticalScroller = YES;
    scrollView.hasHorizontalScroller = NO;
    scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    scrollView.verticalScrollElasticity = NSScrollElasticityAllowed;
    scrollView.horizontalScrollElasticity = NSScrollElasticityNone;
    scrollView.contentView.copiesOnScroll = NO;
    scrollView.usesPredominantAxisScrolling = YES;
    scrollView.backgroundColor = [NSColor colorWithDeviceWhite:227./255. alpha:1.];
    
    [self.view addSubview:scrollView];
    
    ADLTableView* tableView = [[ADLTableView alloc] initWithFrame:self.view.bounds];
    tableView.delegate = self;
    tableView.dataSource = self;
    tableView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    tableView.headerView = nil;
    tableView.backgroundColor = [NSColor clearColor];
    tableView.allowsMultipleSelection = YES;
    tableView.focusRingType = NSFocusRingTypeNone;
    tableView.doubleAction = @selector(cellDoubleClicked:);
    tableView.target = self;
    [tableView setDraggingSourceOperationMask:NSDragOperationMove | NSDragOperationDelete forLocal:YES];
    [tableView registerForDraggedTypes:[NSArray arrayWithObject:kADLItemDragRecordPasteboardType]];
    
    NSTableColumn* column = [[NSTableColumn alloc] initWithIdentifier:@"main column"];
    column.resizingMask = NSTableColumnAutoresizingMask;
    column.width = self.view.frame.size.width;
    [tableView addTableColumn:column];

    
    [scrollView setDocumentView:tableView];
    self.tableView = tableView;
    
    [column release];
    [tableView release];
    [scrollView release];
}

- (void)loadView {
    [super loadView];
    [self viewDidLoad];
}

- (void)didActivate {
    
    // The table view and scroll view widths get out of sync to do various autosizing "magic"
    // While the views initialize
    // Adjust it here for sure, once we've picked a size
    NSRect rect = self.tableView.frame;
    rect.size.width = self.tableView.enclosingScrollView.frame.size.width;
    self.tableView.frame = rect;
    
    
    self.view.nextResponder = self;
    [self.view.window makeFirstResponder:self.tableView];
}

- (void)startEditingSelection {
    NSIndexSet* selection = self.tableView.selectedRowIndexes;
    if(selection.count > 0) {
        NSUInteger editingRow = selection.lastIndex;
        ADLItemView* itemView = [self.tableView viewAtColumn:0 row:editingRow makeIfNecessary:YES];
        [self.tableView scrollRowToVisible:editingRow];
        [itemView beginEditing];
    }

}

- (void)cellDoubleClicked:(NSTableView*)sender {
    [self startEditingSelection];
}

- (BOOL)currentlyEditingRow {
    return self.editingView != nil;
}

- (void)list:(ADLListID *)list changedItemIDsTo:(NSArray *)newOrder {
    // Don't reload if we're in the middle of editing
    // So that if 
    if(self.currentlyEditingRow) {
        return;
    }
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

#pragma mark Table View Delegate
- (void)tableViewShouldClearSelection:(ADLTableView *)tableView {
    [self.tableView selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO];
}

- (void)tableViewShouldEditSelection:(ADLTableView *)tableView {
    [self startEditingSelection];
}

- (void)tableViewShouldToggleSelection:(ADLTableView *)tableView {
    __block BOOL currentlyChecked = YES;
    [self.tableView.selectedRowIndexes enumerateIndexesUsingBlock:^(NSUInteger index, BOOL* stop) {
        currentlyChecked = currentlyChecked && [self.modelAccess completionStatusOfItem:[self.items objectAtIndex:index]];
        *stop = !currentlyChecked;
    }];
    [self.tableView.selectedRowIndexes enumerateIndexesUsingBlock:^(NSUInteger index, BOOL* stop) {
        [self.modelAccess setCompletionStatus:!currentlyChecked ofItem:[self.items objectAtIndex:index]];
    }];
    
}

#pragma mark Data Source

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.items.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    ADLItemView* itemView = [[ADLItemView alloc] initWithFrame:NSMakeRect(0, 0, tableView.bounds.size.width, 90)];
    ADLItemID* item = [self.items objectAtIndex:row];
    itemView.item = item;
    itemView.delegate = self;
    if ([item isNotEqualTo:[NSNull null]]) {
        itemView.title = [self.modelAccess titleOfItem:item];
        itemView.checked = [self.modelAccess completionStatusOfItem:item];
    }
    
    
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
    if(self.view.window.firstResponder == self.tableView) {
        ADLItemID* itemID = [self.items objectAtIndex:row];
        return [ADLItemDragRecord dragRecordWithItemID:itemID];
    }
    else {
        return nil;
    }
}

#pragma mark Item View Delegate

- (void)itemViewDidBeginEditing:(ADLItemView *)item {
    self.editingView = item;
}

- (void)itemViewDidEndEditing:(ADLItemView *)item {
    if(self.editingView == item) {
        self.editingView = nil;
    }
}

- (void)itemViewCancelledEditing:(ADLItemView *)itemView {
    [self.view.window makeFirstResponder:self.tableView];
}

- (void)itemView:(ADLItemView *)itemView changedTitle:(NSString *)newItem {
    if([itemView.item isEqual:[NSNull null]]) {
        NSUInteger index = [self.items indexOfObject:[NSNull null]];
        NSMutableArray* items = [self.items mutableCopy];
        [items removeObjectAtIndex:index];
        self.items = items;
        [items release];
        [self.tableView beginUpdates];
        [self.tableView removeRowsAtIndexes:[NSIndexSet indexSetWithIndex:index] withAnimation:NSTableViewAnimationEffectNone];
        [self.tableView endUpdates];
        [self.tableView setNeedsDisplay];
        
        if([newItem isNotEqualTo:@""]) {
            [self.modelAccess addItemWithTitle:newItem toListWithID:self.listID atIndex:index];
        }
    }
    else {
        [self.modelAccess setTitle:newItem ofItem:itemView.item];
    }
}

- (void)itemView:(ADLItemView *)itemView changedCompletionStatus:(BOOL)status {
    if([itemView.item isEqual:[NSNull null]]) {
        NSUInteger index = [self.items indexOfObject:[NSNull null]];
        NSMutableArray* items = [self.items mutableCopy];
        self.items = items;
        [items release];
        [items removeObjectAtIndex:index];
        [self.tableView beginUpdates];
        [self.tableView removeRowsAtIndexes:[NSIndexSet indexSetWithIndex:index] withAnimation:NSTableViewAnimationEffectGap];
        [self.tableView endUpdates];
    }
    else {
        [self.modelAccess setCompletionStatus:status ofItem:itemView.item];
    }
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
    else if(menuItem.action == @selector(newListItem:)) {
        return YES;
    }
    else {
        return NO;
    }
}

#pragma mark New Item
- (IBAction)newListItem:(id)sender {
    // Clear the editing view so that when we end the current editing session
    // The change still goes through
    self.editingView = nil;
    [self.view.window makeFirstResponder:self.tableView];
    dispatch_async(dispatch_get_main_queue(), ^{
        
        NSIndexSet* selectedIndices = self.tableView.selectedRowIndexes;
        NSUInteger insertionIndex = selectedIndices.count == 0 ? 0 : selectedIndices.lastIndex + 1;
        
        NSMutableArray* items = [self.items mutableCopy];
        [items insertObject:[NSNull null] atIndex:insertionIndex];
        self.items = items;
        [items release];
        
        [self.tableView beginUpdates];
        [self.tableView insertRowsAtIndexes:[NSIndexSet indexSetWithIndex:insertionIndex] withAnimation:NSTableViewAnimationEffectGap];
        [self.tableView endUpdates];
        
        [self.tableView scrollRowToVisible:insertionIndex];
        ADLItemView* itemView = [self.tableView viewAtColumn:0 row:insertionIndex makeIfNecessary:YES];
        [itemView beginEditing];
    });
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
        [self.modelAccess addConcreteItem:item toListWithID:self.listID atIndex:index];
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
