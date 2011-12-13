//
//  ADLItemView.m
//  julep
//
//  Created by Akiva Leffert on 11/9/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ADLItemView.h"

@interface ADLItemView ()

@property (retain, nonatomic) NSTextField* titleView;
@property (retain, nonatomic) NSButton* checkbox;
- (NSRect)textFrameForMainFrame:(NSRect)mainFrame;

@end

@implementation ADLItemView

@synthesize item = mItem;
@synthesize checked = mChecked;
@synthesize checkbox = mCheckbox;
@synthesize delegate = mDelegate;
@synthesize titleView = mTitleView;
@synthesize title = mTitle;

- (id)initWithFrame:(NSRect)frameRect {
    if((self = [super initWithFrame:frameRect])) {
        NSRect textFrame = [self textFrameForMainFrame:frameRect];
        self.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        self.titleView = [[[NSTextField alloc] initWithFrame:textFrame] autorelease];
        self.titleView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        self.titleView.delegate = self;
        self.titleView.backgroundColor = [NSColor clearColor];
        self.titleView.bordered = NO;
        [self addSubview:self.titleView];
        
        self.checkbox = [[[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 18, 18)] autorelease];
        self.checkbox.autoresizingMask = NSViewMinYMargin | NSViewMaxYMargin;
        self.checkbox.buttonType = NSSwitchButton;
        self.checkbox.target = self;
        self.checkbox.action = @selector(toggledCheckbox:);
        [self addSubview:self.checkbox];
    }
    return self;
}

- (void)dealloc {
    self.item = nil;
    self.delegate = nil;
    self.titleView = nil;
    self.checkbox = nil;
    
    [super dealloc];
}

- (NSRect)textFrameForMainFrame:(NSRect)mainFrame {
    return NSMakeRect(30, 0, mainFrame.size.width - 30, mainFrame.size.height);
}

- (void)beginEditing {
    [self.window makeFirstResponder:self.titleView];
}

- (void)setTitle:(NSString *)newTitle {
    NSString* temp = [newTitle copy];
    [mTitle release];
    mTitle = temp;
    
    self.titleView.stringValue = newTitle;
}

- (void)setChecked:(BOOL)checked {
    mChecked = checked;
    self.checkbox.state = checked;
}

#pragma mark Text Field Delegate

- (void)controlTextDidEndEditing:(NSNotification *)obj {
    [self.titleView resignFirstResponder];
    NSString* newTitle = self.titleView.stringValue;
    if (![newTitle isEqualToString:self.title]) {
        [self.delegate itemView:self changedTitle:newTitle];
    }
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    if(commandSelector == @selector(cancelOperation:) && [self.item isEqual:[NSNull null]]) {
        // Clear it so that when we end editing we haven't done anything
        self.titleView.stringValue = @"";
        [self.delegate itemViewCancelledEditing:self];
        return YES;
    }
    return NO;
}

- (void)toggledCheckbox:(id)sender {
    if (self.checkbox.state != self.checked) {
        NSAssert(self.checkbox.state != NSMixedState, @"Can't set checkbox to mixed");
        [self.delegate itemView:self changedCompletionStatus:self.checkbox.state];
    }
}

@end
