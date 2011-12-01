//
//  ADLItemDragRecord.h
//  julep
//
//  Created by Akiva Leffert on 11/30/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ADLModelAccess.h"

@interface ADLItemDragRecord : NSObject <NSPasteboardReading, NSPasteboardWriting, NSCoding>

+ (ADLItemDragRecord*)dragRecordWithItemID:(ADLItemID*)itemID;

@property (readonly, retain, nonatomic) NSURL* itemURL;

@end


extern NSString* kADLItemDragRecordPasteboardType;