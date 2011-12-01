//
//  ADLConcreteItem.m
//  julep
//
//  Created by Akiva Leffert on 11/30/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ADLConcreteItem.h"

#import "ADLModelAccess.h"

@interface ADLConcreteItem ()

@property (retain, nonatomic) NSString* title;
@property (assign, nonatomic) BOOL completionStatus;

@end

@implementation ADLConcreteItem

@synthesize title = mTitle;
@synthesize completionStatus = mCompletionStatus;

+ (ADLConcreteItem*)itemWithTitle:(NSString*)title completionStatus:(BOOL)completionStatus {
    ADLConcreteItem* item = [[[ADLConcreteItem alloc] init] autorelease];
    item.title = title;
    item.completionStatus = completionStatus;
    return item;
}

+ (ADLConcreteItem*)itemWithTask:(CalTask*)task {
    return [self itemWithTitle:task.title completionStatus:task.isCompleted];
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    if((self = [super init])) {
        self.title = [aDecoder decodeObjectForKey:@"title"];
        self.completionStatus = [aDecoder decodeBoolForKey:@"completionStatus"];
    }
    return self;
}

- (void)dealloc {
    self.title = nil;
    
    [super dealloc];
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:self.title forKey:@"title"];
    [aCoder encodeBool:self.completionStatus forKey:@"completionStatus"];
}

+ (NSArray *)readableTypesForPasteboard:(NSPasteboard *)pasteboard {
    return [NSArray arrayWithObject:kADLItemPasteboardType];
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
