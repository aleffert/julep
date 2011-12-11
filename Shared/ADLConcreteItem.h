//
//  ADLConcreteItem.h
//  julep
//
//  Created by Akiva Leffert on 11/30/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CalendarStore/CalendarStore.h>

@interface ADLConcreteItem : NSObject  <NSPasteboardReading, NSPasteboardWriting, NSCoding>

+ (ADLConcreteItem*)itemWithTask:(CalTask*)task;

@property (retain, readonly, nonatomic) NSString* title;
@property (assign, readonly, nonatomic) BOOL completionStatus;
@property (retain, readonly, nonatomic) NSDate* dueDate;
@property (retain, readonly, nonatomic) NSDate* completedDate;
@property (assign, readonly, nonatomic) CalPriority priority;
@property (retain, readonly, nonatomic) NSString* notes;
@property (retain, readonly, nonatomic) NSURL* url;

@end
