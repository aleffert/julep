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
- (KeyCombo)quickCreateKeyCombo;
- (BOOL)hasQuickCreateKeyCombo;
- (void)changedQuickCreateKeyComboTo:(KeyCombo)combo;
@end
