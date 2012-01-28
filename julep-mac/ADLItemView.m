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
        self.titleView = [[[NSTextField alloc] initWithFrame:textFrame] autorelease];
        self.titleView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        self.titleView.delegate = self;
        self.titleView.backgroundColor = [NSColor clearColor];
        self.titleView.bordered = NO;
        self.titleView.focusRingType = NSFocusRingTypeNone;
        [self.titleView.cell setWraps:NO];
        [self addSubview:self.titleView];
        
        self.checkbox = [[[NSButton alloc] initWithFrame:NSMakeRect(14, 4, 18, 18)] autorelease];
        self.checkbox.autoresizingMask = NSViewMaxYMargin;
        self.checkbox.buttonType = NSSwitchButton;
        self.checkbox.target = self;
        self.checkbox.action = @selector(toggledCheckbox:);
        [self addSubview:self.checkbox];
        self.title = @"";
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(styleTitle) name:NSApplicationDidResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(styleTitle) name:NSApplicationDidBecomeActiveNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.item = nil;
    self.delegate = nil;
    self.titleView = nil;
    self.checkbox = nil;
    
    [super dealloc];
}

- (NSRect)textFrameForMainFrame:(NSRect)mainFrame {
    return NSMakeRect(50, 3, mainFrame.size.width - 88, mainFrame.size.height - 9);
}

- (void)beginEditing {
    [self.window makeFirstResponder:self.titleView];
    [self.delegate itemViewDidBeginEditing:self];
}

- (void)styleTitle {
    BOOL active = [[NSApplication sharedApplication] isActive];
    
    NSMutableAttributedString* styledString = [[NSMutableAttributedString alloc] initWithString:self.title];
    NSMutableDictionary* attributes = [NSMutableDictionary dictionary];
    NSMutableParagraphStyle* paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    paragraphStyle.lineBreakMode = NSLineBreakByTruncatingTail;
    [attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
    [paragraphStyle release];
    
    if(self.backgroundStyle == NSBackgroundStyleLight && active) {
        self.titleView.textColor = [NSColor blackColor];
    }
    else if(self.backgroundStyle == NSBackgroundStyleLight) {
        self.titleView.textColor = [NSColor colorWithDeviceWhite:110./255. alpha:1.];
    }
    else if([[NSApplication sharedApplication] isActive]) {
        self.titleView.textColor = [NSColor whiteColor];
        NSShadow* shadow = [[NSShadow alloc] init];
        shadow.shadowColor = [NSColor colorWithDeviceWhite:0. alpha:.5];
        shadow.shadowOffset = NSMakeSize(0, 1);
        shadow.shadowBlurRadius = 1;
        [attributes setObject:shadow forKey:NSShadowAttributeName];;
        [shadow release];
    }    [styledString setAttributes:attributes range:NSMakeRange(0, styledString.length)];

    
    self.titleView.attributedStringValue = styledString;
    
    [styledString release];
}

- (void)setTitle:(NSString *)newTitle {
    NSString* temp = [newTitle copy];
    [mTitle release];
    mTitle = temp;
    self.titleView.stringValue = newTitle;
    [self styleTitle];
}

- (void)setChecked:(BOOL)checked {
    mChecked = checked;
    self.checkbox.state = checked;
}

- (void)setBackgroundStyle:(NSBackgroundStyle)backgroundStyle {
    [super setBackgroundStyle:backgroundStyle];
    [self styleTitle];
}

#pragma mark Text Field Delegate

- (void)controlTextDidEndEditing:(NSNotification *)obj {
    [self.titleView resignFirstResponder];
    NSString* newTitle = self.titleView.stringValue;
    if (![newTitle isEqualToString:self.title]) {
        [self.delegate itemView:self changedTitle:newTitle];
    }
    [self.delegate itemViewDidEndEditing:self];
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
