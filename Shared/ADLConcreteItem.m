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
@property (retain, nonatomic) NSDate* dueDate;
@property (retain, nonatomic) NSDate* completedDate;
@property (assign, nonatomic) CalPriority priority;
@property (retain, nonatomic) NSString* notes;
@property (retain, nonatomic) NSURL* url;

@end

@implementation ADLConcreteItem

@synthesize title = mTitle;
@synthesize completionStatus = mCompletionStatus;
@synthesize dueDate = mDueDate;
@synthesize completedDate = mCompletedDate;
@synthesize priority = mPriority;
@synthesize notes = mNotes;
@synthesize url = mURL;

+ (ADLConcreteItem*)item {
    ADLConcreteItem* item = [[[ADLConcreteItem alloc] init] autorelease];
    return item;
}

+ (ADLConcreteItem*)itemWithTask:(CalTask*)task {
    ADLConcreteItem* item = [self item];
    item.title = task.title;
    item.completionStatus = task.isCompleted;
    item.dueDate = task.dueDate;
    item.completedDate = task.completedDate;
    item.priority = task.priority;
    item.notes = task.notes;
    item.url = task.url;
    return item;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    if((self = [super init])) {
        self.title = [aDecoder decodeObjectForKey:@"title"];
        self.completionStatus = [aDecoder decodeBoolForKey:@"completionStatus"];
        self.dueDate = [aDecoder decodeObjectForKey:@"dueDate"];
        self.completedDate = [aDecoder decodeObjectForKey:@"completedDate"];
        self.priority = [aDecoder decodeIntegerForKey:@"priority"];
        self.notes = [aDecoder decodeObjectForKey:@"notes"];
        self.url = [aDecoder decodeObjectForKey:@"url"];
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
    [aCoder encodeObject:self.dueDate forKey:@"dueDate"];
    [aCoder encodeObject:self.completedDate forKey:@"completedDate"];
    [aCoder encodeInteger:self.priority forKey:@"priority"];
    [aCoder encodeObject:self.notes forKey:@"notes"];
    [aCoder encodeObject:self.url forKey:@"url"];
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
