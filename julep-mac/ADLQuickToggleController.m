//
//  ADLQuickToggleController.m
//  julep
//
//  Created by Akiva Leffert on 12/22/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ADLQuickToggleController.h"

#import "ADLQuickToggleItemView.h"

@interface ADLQuickToggleController ()

@property (retain, nonatomic) IBOutlet NSTextField* entryField;
@property (retain, nonatomic) IBOutlet NSTableView* itemTable;

- (IBAction)done:(id)sender;
- (IBAction)toggle:(id)sender;

@end

@implementation ADLQuickToggleController

@synthesize entryField = mEntryField;
@synthesize itemTable = mItemTable;
@synthesize items = mItems;
@synthesize delegate = mDelegate;

- (void)dealloc {
    self.entryField = nil;
    self.itemTable = nil;
    self.items = nil;
    [super dealloc];
}

- (NSString*)windowNibName {
    return @"ADLQuickToggle";
}

- (void)windowDidLoad {
    [super windowDidLoad];
    self.window.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorTransient;
}

- (void)showWindow:(id)sender {
    [self.itemTable reloadData];
    [self.itemTable selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    self.entryField.stringValue = @"";
    [super showWindow:sender];
    [self.window makeKeyAndOrderFront:self];
    [self.window makeFirstResponder:self.entryField];
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
}

- (void)updateItemsTo:(NSArray*)items {
    self.items = items;
    [self.itemTable reloadData];
    [self.itemTable selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
}

- (IBAction)toggle:(id)sender {
    NSURL* itemURL = [[self.items objectAtIndex:self.itemTable.selectedRow] objectForKey:@"url"];
    [self.delegate toggleItemWithURL:itemURL];
    
    [self.window performClose:sender];
}

- (IBAction)done:(id)sender {
    [self.window performClose:sender];
}

- (void)windowDidResignKey:(NSNotification *)notification {
    self.items = [NSArray array];
    [self.window performClose:nil];
}

- (void)controlTextDidChange:(NSNotification *)obj {
    self.items = [self.delegate itemsWithSearchString:self.entryField.stringValue];
    [self.itemTable reloadData];
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    if(commandSelector == @selector(moveUp:)) {
        NSInteger index = self.itemTable.selectedRow;
        if(index > 0) {
            [self.itemTable selectRowIndexes: [NSIndexSet indexSetWithIndex: index - 1] byExtendingSelection:NO];
            [self.itemTable scrollRowToVisible:index - 1];
        }
        return YES;
    }
    if(commandSelector == @selector(moveDown:)) {
        NSInteger index = self.itemTable.selectedRow;
        if(index + 1 < self.items.count) {
            [self.itemTable selectRowIndexes:[NSIndexSet indexSetWithIndex:index + 1] byExtendingSelection:NO];
            [self.itemTable scrollRowToVisible:index + 1];
        }
        return YES;
    }
    return NO;
}

- (void)toggleTableViewRow:(id)sender {
    [self.itemTable.selectedRowIndexes enumerateIndexesUsingBlock:^(NSUInteger index, BOOL* stop) {
        ADLQuickToggleItemView* itemView = [self.itemTable viewAtColumn:0 row:index makeIfNecessary:YES];
        [self.delegate toggleItemWithURL:itemView.objectValue];
    }];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.items.count;
}

- (void)tableView:(NSTableView *)tableView didAddRowView:(NSTableRowView *)rowView forRow:(NSInteger)row {
    NSDictionary* item = [self.items objectAtIndex:row];
    ADLQuickToggleItemView* cell = [rowView viewAtColumn:0];
    cell.listLabel.stringValue = [item objectForKey:@"list"];
    cell.titleView.title = [item objectForKey:@"title"];
    cell.titleView.state = [[item objectForKey:@"status"] integerValue];
    cell.objectValue = [item objectForKey:@"url"];
    cell.titleView.target = self;
    cell.titleView.action = @selector(toggleTableViewRow:);
}

@end
