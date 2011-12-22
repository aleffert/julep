//
//  ADLPreferencesController.h
//  julep
//
//  Created by Akiva Leffert on 12/18/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ShortcutRecorder/ShortcutRecorder.h>

#import "ADLModelAccess.h"

@protocol ADLPreferencesControllerDelegate;

@interface ADLPreferencesController : NSWindowController <NSTableViewDataSource, NSTableViewDelegate, ADLCollectionChangedListener>

@property (retain, nonatomic) ADLModelAccess* modelAccess;
@property (copy, nonatomic) NSArray* listIDs; // List IDs
@property (assign, nonatomic) id<ADLPreferencesControllerDelegate> delegate;

@end

@protocol ADLPreferencesControllerDelegate <NSObject>

- (KeyCombo)keyComboForIdentifier:(NSString*)identifier;
- (BOOL)hasKeyComboForIdentifier:(NSString*)identifier;
- (void)changedKeyComboTo:(KeyCombo)combo forIdentifier:(NSString*)identifier;

@end

extern NSString* kADLQuickCreateHotKeyIdentifier;
extern NSString* kADLQuickToggleHotKeyIdentifier;