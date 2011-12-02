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

+ (ADLConcreteItem*)itemWithTitle:(NSString*)title completionStatus:(BOOL)completionStatus;
+ (ADLConcreteItem*)itemWithTask:(CalTask*)task;

@property (retain, readonly, nonatomic) NSString* title;
@property (assign, readonly, nonatomic) BOOL completionStatus;

@end