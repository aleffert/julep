//
//  NSDate+ADLAdditions.m
//  julep
//
//  Created by Akiva Leffert on 11/26/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "NSDate+ADLAdditions.h"

@implementation NSDate (ADLAdditions)


+ (NSDate*)yesterdayMorning {
    NSCalendar* calendar = [NSCalendar currentCalendar];
    NSDate* now = [NSDate date];
    NSDateComponents* todayComponents = [calendar components:NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit fromDate:now];

    NSDate* thisMorning = [calendar dateFromComponents:todayComponents];
    
    NSDateComponents* previousDayComponents = [[NSDateComponents alloc] init];
    previousDayComponents.day = -1;
    
    NSDate* yesterdayMorning = [calendar dateByAddingComponents:previousDayComponents toDate:thisMorning options:0];
    
    [previousDayComponents release];
    return yesterdayMorning;
}

+ (NSDate*)earlyTomorrowMorning {
    NSCalendar* calendar = [NSCalendar currentCalendar];
    NSDate* now = [NSDate date];
    NSDateComponents* todayComponents = [calendar components:NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit fromDate:now];
    
    NSDate* thisMorning = [calendar dateFromComponents:todayComponents];
    NSDateComponents* nextDayComponents = [[NSDateComponents alloc] init];
    nextDayComponents.day = 1;
    nextDayComponents.hour = 2; // 2am
    NSDate* tomorrowMorning = [calendar dateByAddingComponents:nextDayComponents toDate:thisMorning options:0];
    
    [nextDayComponents release];
    
    return tomorrowMorning;

}

@end
