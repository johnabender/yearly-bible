//
//  BRReadingManager.h
//  bible-reading
//
//  Created by John Bender on 1/5/14.
//  Copyright (c) 2014 Bender Systems. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>

#import "BRReading.h"


FOUNDATION_EXPORT NSString* const BRNotificationCategory;
FOUNDATION_EXPORT NSString* const BRNotificationActionMarkRead;

FOUNDATION_EXPORT NSString* const BRMarkReadString;


typedef NS_ENUM(NSInteger, BRReadingType) {
    BRReadingTypeSequential,
    BRReadingTypeTopical
};


@interface BRReadingManager : NSObject <UNUserNotificationCenterDelegate>

+(BRReadingManager*) sharedReadingManager;
-(void) registerForNotifications;

+(NSArray*) readings;

+(BRReadingType) readingType;
+(void) setReadingType:(BRReadingType)newType;

+(BOOL) isReadingScheduleSet;
+(NSString*) readingSchedule;
+(void) setReadingSchedule:(NSString*)scheduleTime;
+(void) setReadingScheduleWithDate:(NSDate*)scheduleDate;

+(NSArray*) resetReadings;

+(NSArray*) shiftReadings:(NSInteger)offset;

+(void) readingWasRead:(BRReading*)reading;
+(void) readingWasUnread:(BRReading*)reading;

+(NSString*) firstDay;

+(void) updateScheduledNotifications;

@end
