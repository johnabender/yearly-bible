//
//  BRReadingManager.h
//  bible-reading
//
//  Created by John Bender on 1/5/14.
//  Copyright (c) 2014 Bender Systems. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>

#import "BRTranslation.h"

@class Book;
@class Passage;
@class Reading;


FOUNDATION_EXPORT NSString* const BRNotificationCategory;
FOUNDATION_EXPORT NSString* const BRNotificationActionMarkRead;

FOUNDATION_EXPORT NSString* const BRMarkReadString;


typedef NS_ENUM(NSInteger, BRReadingType) {
    BRReadingTypeSequential = 0,
    BRReadingTypeTopical,
    BRReadingTypeChronological
};

typedef NS_ENUM(NSInteger, BRReadingViewType) {
    BRReadingViewTypeDarkText = 0,
    BRReadingViewTypeLightText
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

+(BRReadingViewType) readingViewType;
+(void) setReadingViewType:(BRReadingViewType)newType;

+(BRTranslation*) preferredTranslation;
+(void) setPreferredTranslation:(BRTranslation*)newPreferredTranslation;

+(void) readingWasRead:(Reading*)reading;
+(void) readingWasUnread:(Reading*)reading;

+(NSString*) firstDay;

+(void) updateScheduledNotifications;

@end
