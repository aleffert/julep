//
//  ADLPreferencesController.m
//  julep
//
//  Created by Akiva Leffert on 12/18/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ADLPreferencesController.h"

#import "CalCalendarStore+ADLAdditions.h"

#import <ShortcutRecorder/ShortcutRecorder.h>

@interface ADLPreferencesController ()

@property (retain, nonatomic) IBOutlet NSTableView* badgeCalendarsTable;
@property (retain, nonatomic) IBOutlet SRRecorderControl* quickCreateKeyComboRecorder;

@end

@implementation ADLPreferencesController

@synthesize quickCreateKeyComboRecorder = mQuickCreateKeyComboRecorder;
@synthesize badgeCalendarsTable = mBadgeCalendarsTable;
@synthesize listIDs = mListIDs;
@synthesize modelAccess = mModelAccess;
@synthesize delegate = mDelegate;

- (void)dealloc {
    [self.modelAccess removeCollectionChangedListener:self];
    self.listIDs = nil;
    self.modelAccess = nil;
    self.badgeCalendarsTable = nil;
    self.quickCreateKeyComboRecorder = nil;
    [super dealloc];
}

- (NSString*)windowNibName {
    return @"ADLPreferences";
}

- (void)windowDidLoad {
    [super windowDidLoad];
    [self.modelAccess addCollectionChangedListener:self];
    if([self.delegate hasQuickCreateKeyCombo]) {
        self.quickCreateKeyComboRecorder.keyCombo = self.delegate.quickCreateKeyCombo;
    }
}

- (void)updatedStatusOfCellInTableView:(NSTableView*)tableView {
    ADLListID* listID = [self.listIDs objectAtIndex:tableView.clickedRow];
    BOOL status = [self.modelAccess showsCountInBadgeForList:listID];
    [self.modelAccess setShowsCountInBadge:!status forList:listID];
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

- (void)tableView:(NSTableView *)tableView willDisplayCell:(NSButtonCell*)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    cell.title = [self.modelAccess titleOfList:[self.listIDs objectAtIndex:row]];
    cell.state = [self.modelAccess showsCountInBadgeForList:[self.listIDs objectAtIndex:row]];
    cell.target = self;
    cell.action = @selector(updatedStatusOfCellInTableView:);
}

- (void)changedListsIDsTo:(NSArray *)newOrder {
    self.listIDs = newOrder;
    [self.badgeCalendarsTable reloadData];
}

- (void)shortcutRecorder:(SRRecorderControl *)aRecorder keyComboDidChange:(KeyCombo)newKeyCombo {
    [self.delegate changedQuickCreateKeyComboTo:newKeyCombo];
}

@end
