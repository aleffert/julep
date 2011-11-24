//
//  CalCalendarStore+ADLAdditions.m
//  julep
//
//  Created by Akiva Leffert on 10/14/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "CalCalendarStore+ADLAdditions.h"

#import <CoreData/CoreData.h>

@interface CalCalendar(Private)

@property(retain, nonatomic) id group;

@end

@interface CalCalendarStore(Private)

+ (NSManagedObjectContext*)managedObjectContextForUser;

@end

@interface NSObject(CalPrivateAdditions)
- (NSManagedObjectID*) managedObjectID;
- (NSArray*)reminderCalendars;
@end


@implementation CalCalendarStore(ADLAdditions)

- (NSArray*)reminderCalendars {
    
    NSMutableArray* result = [NSMutableArray array];
    NSManagedObjectContext* context = [CalCalendarStore managedObjectContextForUser];
    for(CalCalendar* calendar in self.calendars) {
        id group = calendar.group;
        NSManagedObjectID* objectID = [group managedObjectID];
        id managedGroup = [context objectWithID:objectID];
        NSArray* managedCalendars = [managedGroup reminderCalendars];
        id managedCalendar = [context objectWithID:[calendar managedObjectID]];
        if([managedCalendars containsObject:managedCalendar]) {
            [result addObject:calendar];
        }
    }
    
    return result;
}

- (BOOL)isReminderCalendar:(CalCalendar *)calendar {
    return [self.reminderCalendars containsObject:calendar];
}

@end