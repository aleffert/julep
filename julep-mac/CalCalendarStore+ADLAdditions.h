//
//  CalCalendarStore+ADLAdditions.h
//  julep
//
//  Created by Akiva Leffert on 10/14/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CalendarStore/CalendarStore.h>

// Isolate private API calls

@interface CalCalendarStore (ADLAdditions)

- (NSArray*)reminderCalendars;
- (BOOL)isReminderCalendar:(CalCalendar*)calendar;

@end