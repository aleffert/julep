//
//  ADLListsWindowController.m
//  julep
//
//  Created by Akiva Leffert on 9/17/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ADLListsWindowController.h"

#import "ADLDocumentViewController.h"
#import "ADLListsDocument.h"
#import "ADLModelAccess.h"


static NSString* kADLJulepTitle = @"Julep";

@interface ADLListsWindowController ()

@property (retain, nonatomic) ADLDocumentViewController* documentViewController;

@end


@implementation ADLListsWindowController

@synthesize documentViewController = mDocumentViewController;

- (void)dealloc {
    self.documentViewController = nil;
    [super dealloc];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    self.documentViewController = [[[ADLDocumentViewController alloc] initWithModel:self.document.modelAccess] autorelease];
    
    NSView* contentView = self.window.contentView;
    [self.window.contentView addSubview:self.documentViewController.view];
    [self.documentViewController wasAddedToWindow];
    
    self.documentViewController.view.frame = contentView.bounds;
    
    self.documentViewController.nextResponder = self.nextResponder;
    self.nextResponder = self.documentViewController;
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window {
    return self.document.modelAccess.undoManager;
}

- (void)synchronizeWindowTitleWithDocumentName {
    self.window.title = kADLJulepTitle;
    self.window.representedURL = nil;
}

@end
