//
//  ADLNewItemController.m
//  julep
//
//  Created by Akiva Leffert on 12/21/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ADLNewItemController.h"

@interface ADLNewItemController ()

@property (retain, nonatomic) IBOutlet NSButton* cancelButton;
@property (retain, nonatomic) IBOutlet NSButton* createButton;
@property (retain, nonatomic) IBOutlet NSTextField* entryField;
@property (retain, nonatomic) IBOutlet NSTableView* listTable;

- (IBAction)cancel:(id)sender;
- (IBAction)create:(id)sender;

@end

@implementation ADLNewItemController

@synthesize cancelButton = mCancelButton;
@synthesize createButton = mCreateButton;
@synthesize delegate = mDelegate;
@synthesize entryField = mEntryField;
@synthesize listTable = mListTable;
@synthesize listIDs = mListIDs;
@synthesize listNames = mListNames;

- (void)dealloc {
    self.listIDs = nil;
    self.listNames = nil;
    self.cancelButton = nil;
    self.createButton = nil;
    self.entryField = nil;
    self.listTable = nil;
    [super dealloc];
}

- (NSString*)windowNibName {
    return @"ADLNewItem";
}

- (void)windowDidLoad {
    [super windowDidLoad];
    self.window.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorTransient;
}

- (void)showWindow:(id)sender {
    [self.listTable reloadData];
    [self.listTable selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    self.entryField.stringValue = @"";
    [super showWindow:sender];
    [self.window makeKeyAndOrderFront:self];
    [self.window makeFirstResponder:self.entryField];
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.listIDs.count;
}

- (NSCell*)tableView:(NSTableView *)tableView dataCellForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    return tableColumn.dataCell;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    return [self.listIDs objectAtIndex:row];
}

- (void)tableView:(NSTableView *)tableView willDisplayCell:(NSTextFieldCell*)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    cell.title = [self.listNames objectAtIndex:row];
}

- (IBAction)create:(id)sender {
    NSString* title = self.entryField.stringValue;
    NSURL* listID = [self.listIDs objectAtIndex: self.listTable.selectedRow];
    
    if(title.length > 0) {
        [self.delegate addItemWithTitle: title toList:listID];
    }
    
    [self.window performClose:sender];
}

- (IBAction)cancel:(id)sender {
    [self.window performClose:sender];
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    if(commandSelector == @selector(moveUp:)) {
        NSInteger index = self.listTable.selectedRow;
        if(index > 0) {
            [self.listTable selectRowIndexes: [NSIndexSet indexSetWithIndex: index - 1] byExtendingSelection:NO];
            [self.listTable scrollRowToVisible:index - 1];
        }
        return YES;
    }
    if(commandSelector == @selector(moveDown:)) {
        NSInteger index = self.listTable.selectedRow;
        if(index + 1 < self.listIDs.count) {
            [self.listTable selectRowIndexes:[NSIndexSet indexSetWithIndex:index + 1] byExtendingSelection:NO];
            [self.listTable scrollRowToVisible:index + 1];
        }
        return YES;
    }
    return NO;
}

- (void)windowDidResignKey:(NSNotification *)notification {
    self.listIDs = [NSArray array];
    [self.window performClose:nil];
}

@end
