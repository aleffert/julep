//
//  ADLQuickToggleItemView.h
//  julep
//
//  Created by Akiva Leffert on 12/22/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <AppKit/AppKit.h>

@interface ADLQuickToggleItemView : NSTableCellView

@property (retain, nonatomic) IBOutlet NSTextField* listLabel;
@property (retain, nonatomic) IBOutlet NSButton* titleView;

@end
