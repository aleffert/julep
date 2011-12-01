//
//  ADLItemDragRecord.m
//  julep
//
//  Created by Akiva Leffert on 11/30/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ADLItemDragRecord.h"

NSString* kADLItemDragRecordPasteboardType = @"com.akivaleffert.julep.DragRecordType";

@interface ADLItemDragRecord ()

@property (retain, nonatomic) NSURL* itemURL;

@end

@implementation ADLItemDragRecord

@synthesize itemURL = mItemURL;

+ (id)dragRecordWithItemID:(ADLItemID*)itemID {
    ADLItemDragRecord* record = [[ADLItemDragRecord alloc] init];
    record.itemURL = itemID.URIRepresentation;
    return [record autorelease];
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    if((self = [super init])) {
        self.itemURL = [aDecoder decodeObjectForKey:@"itemURL"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:self.itemURL forKey:@"itemURL"];
}

+ (NSArray *)readableTypesForPasteboard:(NSPasteboard *)pasteboard {
    return [NSArray arrayWithObject:kADLItemDragRecordPasteboardType];
}

+ (NSPasteboardReadingOptions)readingOptionsForType:(NSString *)type pasteboard:(NSPasteboard *)pasteboard {
    return NSPasteboardReadingAsKeyedArchive;
}

- (NSArray *)writableTypesForPasteboard:(NSPasteboard *)pasteboard {
    return [[self class] readableTypesForPasteboard:pasteboard];
}

- (id)pasteboardPropertyListForType:(NSString *)type {
    return [NSKeyedArchiver archivedDataWithRootObject:self];
}

@end
