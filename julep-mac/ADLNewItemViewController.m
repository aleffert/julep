//
//  ADLNewItemViewController.m
//  julep
//
//  Created by Akiva Leffert on 11/20/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ADLNewItemViewController.h"

@interface ADLNewItemViewController ()


@property (retain, nonatomic) IBOutlet NSButton* cancelButton;
@property (retain, nonatomic) IBOutlet NSButton* createButton;
@property (retain, nonatomic) IBOutlet NSTextField* entryField;
@property (retain, nonatomic) IBOutlet NSPopUpButton* listPopup;

@end

@implementation ADLNewItemViewController

@synthesize cancelButton = mCancelButton;
@synthesize createButton = mCreateButton;
@synthesize entryField = mEntryField;
@synthesize listPopup = mListPopup;
@synthesize itemTitle = mItemTitle;

- (void)willPresentAsSheet {
    self.view.window.initialFirstResponder = self.entryField;
    self.view.window.defaultButtonCell = self.createButton.cell;
}

- (void)createItem:(id)sender {
    [NSApp endSheet:self.view.window returnCode:ADLNewItemCreateReturnCode];
}

- (void)cancelCreation:(id)sender {
    [NSApp endSheet:self.view.window returnCode:ADLNewItemCancelReturnCode];
}

- (void)addListID:(ADLListID*)list withName:(NSString*)name {
    [self.listPopup addItemWithTitle:name];
    NSInteger index = self.listPopup.itemArray.count - 1;
    NSMenuItem* menu = [self.listPopup itemAtIndex:index];
    menu.representedObject = list;
}

- (void)setItemTitle:(NSString *)itemTitle {
    NSAssert(self.entryField != nil, @"Touching entry field without loading new item view");
    self.entryField.stringValue = itemTitle;
}

- (NSString*)itemTitle {
    NSAssert(self.entryField != nil, @"Touching entry field without loading new item view");
    return self.entryField.stringValue;
}

- (ADLListID*)selectedList {
    NSAssert(self.listPopup != nil, @"Touching selected list without loading new item view");
    return self.listPopup.selectedItem.representedObject;
}

- (void)setSelectedList:(ADLListID*)newSelection {
    NSAssert(self.listPopup != nil, @"Touching selected list without loading new item view");
    NSInteger index = [self.listPopup indexOfItemWithRepresentedObject:newSelection];
    [self.listPopup selectItemAtIndex:index];
}

@end
