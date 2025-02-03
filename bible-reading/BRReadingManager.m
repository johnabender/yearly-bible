//
//  BRReadingManager.m
//  bible-reading
//
//  Created by John Bender on 1/5/14.
//  Copyright (c) 2014 Bender Systems. All rights reserved.
//

#import "BRReadingManager.h"
#import "bible_reading-Swift.h"


NSString* const BRNotificationCategory = @"BRReadingReminderCategory";
NSString* const BRNotificationActionMarkRead = @"BRMarkReadAction";

NSString* const BRMarkReadString = @"Mark as Read";

static NSString* const BRReadingSchedulePreference = @"BRReadingSchedulePreference"; // deprecated in v2.0.3
static NSString* const BRReadingScheduleTimePreference = @"BRReadingScheduleTimePreference";

static NSString* const BRReadingTypePreference = @"BRReadingTypePreference";

static NSString* const BRReadingViewTypePreference = @"BRReadingViewTypePreference";
static NSString* const BRTranslationPreference = @"BRTranslationPreference";


@implementation BRReadingManager

static NSArray *readings = nil;
static NSString *firstDay = nil;
static NSDateFormatter *scheduleTimeFormatter = nil;

+(void) initialize
{
    scheduleTimeFormatter = [NSDateFormatter new];
    scheduleTimeFormatter.dateFormat = @"HH:mm";
}


+(BRReadingManager*) sharedReadingManager
{
    static BRReadingManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [BRReadingManager new];
    });

    return shared;
}

-(void) registerForNotifications
{
    UNNotificationAction *action = [UNNotificationAction actionWithIdentifier:BRNotificationActionMarkRead
                                                                        title:BRMarkReadString
                                                                      options:0];
    UNNotificationCategory *category = [UNNotificationCategory categoryWithIdentifier:BRNotificationCategory
                                                                              actions:@[action]
                                                                    intentIdentifiers:@[]
                                                                              options:0];
    [[UNUserNotificationCenter currentNotificationCenter] setNotificationCategories:[NSSet setWithObject:category]];

    [[UNUserNotificationCenter currentNotificationCenter] setDelegate:self];
}


+(NSArray*) readings
{
    if( !readings ) {
        NSArray *r = [NSArray arrayWithContentsOfURL:[self fileURL:[self readingType]]];
        if( [r count] ) {
            NSMutableArray *_readings = [NSMutableArray arrayWithCapacity:[r count]];
            for( NSDictionary *dict in r ) {
                Reading *reading = [[Reading alloc] initWithDictionary:dict];
                [_readings addObject:reading];
            }
            [self fixReadings:_readings];
        }
        else
            [self resetReadings];

        [self updateFirstDay];
    }

    return readings;
}

+(NSArray*) dictionaryArrayFromReadingArray:(NSArray*)_readings
{
    NSMutableArray *dicts = [NSMutableArray arrayWithCapacity:[_readings count]];
    for( Reading *reading in _readings )
        [dicts addObject:[reading dictionaryRepresentation]];
    return [NSArray arrayWithArray:dicts];
}


#pragma mark - Reading type

+(BRReadingType) readingType
{
    return (BRReadingType)[[NSUserDefaults standardUserDefaults] integerForKey:BRReadingTypePreference];
}

+(void) setReadingType:(BRReadingType)newType
{
    if( newType != [self readingType] ) {
        readings = nil;
        [[NSUserDefaults standardUserDefaults] setInteger:newType forKey:BRReadingTypePreference];
    }
}


#pragma mark - Reading schedule

+(BOOL) isReadingScheduleSet
{
    return ([self readingSchedule] != nil);
}

+(NSString*) readingSchedule
{
    NSString *scheduleTime = [[NSUserDefaults standardUserDefaults] objectForKey:BRReadingScheduleTimePreference];
    if( [scheduleTime isKindOfClass:[NSString class]] )
        return scheduleTime;

    NSDate *legacyDate = [[NSUserDefaults standardUserDefaults] objectForKey:BRReadingSchedulePreference];
    if( [legacyDate isKindOfClass:[NSDate class]] )
        return [scheduleTimeFormatter stringFromDate:legacyDate];

    return nil;
}

+(void) setReadingSchedule:(NSString*)scheduleTime
{
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:BRReadingSchedulePreference];

    if( scheduleTime == nil )
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:BRReadingScheduleTimePreference];
    else
        [[NSUserDefaults standardUserDefaults] setObject:scheduleTime forKey:BRReadingScheduleTimePreference];
}

+(void) setReadingScheduleWithDate:(NSDate*)scheduleDate
{
    [self setReadingSchedule:[scheduleTimeFormatter stringFromDate:scheduleDate]];
}


+(void) readingWasRead:(Reading*)reading
{
    reading.read = TRUE;
    [self save];
}

+(void) readingWasUnread:(Reading*)reading
{
    reading.read = FALSE;
    [self save];
}


#pragma mark - Reading view preferences

+(BRReadingViewType) readingViewType
{
    return [[NSUserDefaults standardUserDefaults] integerForKey:BRReadingViewTypePreference];
}

+(void) setReadingViewType:(BRReadingViewType)newType
{
    [[NSUserDefaults standardUserDefaults] setInteger:newType forKey:BRReadingViewTypePreference];
}


+(BRTranslation*) preferredTranslation
{
    NSDictionary *storedPreference = [[NSUserDefaults standardUserDefaults] dictionaryForKey:BRTranslationPreference];
    if( storedPreference == nil ) return nil;
    return [[BRTranslation alloc] initWithDictionary:storedPreference];
}

+(void) setPreferredTranslation:(BRTranslation*)newPreferredTranslation
{
    [[NSUserDefaults standardUserDefaults] setObject:[newPreferredTranslation dictionaryRepresentation]
                                              forKey:BRTranslationPreference];
}


+(NSArray*) resetReadings
{
    readings = [self newReadings:[self readingType]];
    [self save];
    return readings;
}


+(NSArray*) shiftReadings:(NSInteger)offset
{
    assert( offset < [readings count] );
    
    NSMutableArray *newReadings = [NSMutableArray arrayWithCapacity:[readings count]];
    NSArray *unshiftedReadings = [self newReadings:[self readingType]];

    NSInteger i = offset, j = 0;
    for( ; i < [readings count]; i++, j++ ) {
        Reading *ur = unshiftedReadings[j];
        Reading *sr = readings[i];
        Reading *pr = readings[j];
        ur.day = sr.day;
        ur.read = pr.read;
        [newReadings addObject:ur];
    }
    for( ; [newReadings count] < [readings count]; i++, j++ ) {
        Reading *ur = unshiftedReadings[j];
        Reading *sr = readings[i - [readings count]];
        Reading *pr = readings[j];
        ur.day = sr.day;
        ur.read = pr.read;
        [newReadings addObject:ur];
    }

    readings = newReadings;
    [self save];

    return readings;
}


+(void) fixReadings:(NSArray*)existingReadings
{
    // update chapters to match what they are in code
    NSArray *newReadings = [self newReadings:[self readingType]];
    assert( [existingReadings count] == [newReadings count] );

    NSMutableArray *fixedReadings = [NSMutableArray arrayWithCapacity:[existingReadings count]];
    for( NSInteger i = 0; i < [existingReadings count]; i++ ) {
        Reading *nr = newReadings[i];
        Reading *er = existingReadings[i];
        if( ![nr.day isEqualToString:er.day] ) {
            readings = existingReadings;
            return; // can't fix chapter if offset, because what reading matches?
        }

        nr.read = er.read;
        [fixedReadings addObject:nr];
    }

    readings = [NSArray arrayWithArray:fixedReadings];
    [self save];
}


+(NSURL*) fileURL:(BRReadingType)readingType
{
    NSURL *documentsPath = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    NSString *fileName = [NSString stringWithFormat:@"My Readings (%d).plist", ((int)[self readingType])];
    return [documentsPath URLByAppendingPathComponent:fileName];
}


+(void) save
{
    NSArray *dicts = [self dictionaryArrayFromReadingArray:[self readings]];
    [dicts writeToURL:[self fileURL:[self readingType]] atomically:YES];

    [self updateFirstDay];
    [self updateScheduledNotifications];
}


+(void) updateFirstDay
{
    Reading *first = readings[0];
    firstDay = first.day;
}


+(NSString*) firstDay
{
    return firstDay;
}


+(void) updateScheduledNotifications
{
    if( [self readingSchedule] == nil ) return;

    [[UNUserNotificationCenter currentNotificationCenter] removeAllPendingNotificationRequests];

    // choose reading
    Reading *reading = nil;
    for( reading in [self readings] )
        if( !reading.read )
            break;
    if( reading == nil )
        reading = [self readings][0];

    // notify repeatedly

    NSString *readingText = [NSString stringWithFormat:@"%@: %@", reading.day, reading.displayText];

    UNMutableNotificationContent *content = [UNMutableNotificationContent new];
    content.categoryIdentifier = BRNotificationCategory;
    content.body = readingText;
    content.userInfo = [reading dictionaryRepresentation];

    NSString *scheduleString = [self readingSchedule];
    NSDateComponents *triggerTime = [NSDateComponents new];
    triggerTime.hour = [[scheduleString substringToIndex:2] integerValue]; // assumes "HH:mm" in scheduleTimeFormatter
    triggerTime.minute = [[scheduleString substringFromIndex:3] integerValue];
    UNCalendarNotificationTrigger *trigger = [UNCalendarNotificationTrigger triggerWithDateMatchingComponents:triggerTime repeats:YES];

    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:readingText
                                                                          content:content
                                                                          trigger:trigger];
    [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request
                                                           withCompletionHandler:nil];
}


#pragma mark - UNUserNotificationCenterDelegate

-(void) userNotificationCenter:(UNUserNotificationCenter *)center
didReceiveNotificationResponse:(UNNotificationResponse *)response
         withCompletionHandler:(void (^)(void))completionHandler
{
    if( [response.actionIdentifier isEqualToString:BRNotificationActionMarkRead] ) {
        Reading *readingToMark = [[Reading alloc] initWithDictionary:response.notification.request.content.userInfo];

        for( Reading *reading in [[self class] readings] ) {
            if( [reading isEqual:readingToMark] ) {
                [[self class] readingWasRead:reading];
                break;
            }
        }
    }

    completionHandler();
}


+(NSArray*) newReadings:(BRReadingType)readingType
{
    switch( readingType ) {
#pragma mark Topical
        case BRReadingTypeTopical:
            return @[
                [[Reading alloc] initWithDay:@"Jan. 1" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:1
                                    endingChapter:2],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 2" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJoshua]
                                  startingChapter:1
                                    endingChapter:6],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 3" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:1
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 4" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJob]
                                  startingChapter:1
                                    endingChapter:2],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 5" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexIsaiah]
                                  startingChapter:1
                                    endingChapter:5],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 6" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                  startingChapter:1
                                    endingChapter:3],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 7" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexRomans]
                                  startingChapter:1
                                    endingChapter:2],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 8" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:3
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 9" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJoshua]
                                  startingChapter:7
                                    endingChapter:11],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 10" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:5
                                    endingChapter:7],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 11" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJob]
                                  startingChapter:3
                                    endingChapter:5],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 12" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexIsaiah]
                                  startingChapter:6
                                    endingChapter:10],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 13" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                  startingChapter:4
                                    endingChapter:5],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 14" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexRomans]
                                  startingChapter:3
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 15" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:5
                                    endingChapter:8],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 16" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJoshua]
                                  startingChapter:12
                                    endingChapter:17],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 17" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:8
                                    endingChapter:11],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 18" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJob]
                                  startingChapter:6
                                    endingChapter:7],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 19" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexIsaiah]
                                  startingChapter:11
                                    endingChapter:15],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 20" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                  startingChapter:6
                                    endingChapter:7],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 21" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexRomans]
                                  startingChapter:5
                                    endingChapter:7],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 22" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:9
                                    endingChapter:11],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 23" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJoshua]
                                  startingChapter:18
                                    endingChapter:21],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 24" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:12
                                    endingChapter:17],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 25" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJob]
                                  startingChapter:8
                                    endingChapter:10],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 26" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexIsaiah]
                                  startingChapter:16
                                    endingChapter:22],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 27" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                  startingChapter:8
                                    endingChapter:10],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 28" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexRomans]
                                  startingChapter:8
                                    endingChapter:9],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 29" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:12
                                    endingChapter:14],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 30" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJoshua]
                                  startingChapter:22
                                    endingChapter:24],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 31" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                       oneChapter:18],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 1" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJob]
                                  startingChapter:11
                                    endingChapter:14],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 2" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexIsaiah]
                                  startingChapter:23
                                    endingChapter:26],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 3" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                  startingChapter:11
                                    endingChapter:13],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 4" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexRomans]
                                  startingChapter:10
                                    endingChapter:11],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 5" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:15
                                    endingChapter:17],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 6" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJudges]
                                  startingChapter:1
                                    endingChapter:5],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 7" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:19
                                    endingChapter:21],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 8" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJob]
                                  startingChapter:15
                                    endingChapter:17],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 9" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexIsaiah]
                                  startingChapter:27
                                    endingChapter:30],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 10" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                  startingChapter:14
                                    endingChapter:16],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 11" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexRomans]
                                  startingChapter:12
                                    endingChapter:13],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 12" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:18
                                    endingChapter:20],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 13" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJudges]
                                  startingChapter:6
                                    endingChapter:9],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 14" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:22
                                    endingChapter:23],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 15" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJob]
                                  startingChapter:18
                                    endingChapter:19],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 16" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexIsaiah]
                                  startingChapter:31
                                    endingChapter:35],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 17" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                  startingChapter:17
                                    endingChapter:18],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 18" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexRomans]
                                  startingChapter:14
                                    endingChapter:16],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 19" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:21
                                    endingChapter:23],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 20" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJudges]
                                  startingChapter:10
                                    endingChapter:16],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 21" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:24
                                    endingChapter:26],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 22" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJob]
                                  startingChapter:20
                                    endingChapter:22],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 23" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexIsaiah]
                                  startingChapter:36
                                    endingChapter:40],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 24" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                  startingChapter:19
                                    endingChapter:20],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 25" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexCorinthians1]
                                  startingChapter:1
                                    endingChapter:3],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 26" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:24
                                    endingChapter:25],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 27" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJudges]
                                  startingChapter:17
                                    endingChapter:21],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 28" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:27
                                    endingChapter:29],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 1" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJob]
                                  startingChapter:23
                                    endingChapter:24],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 2" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexIsaiah]
                                  startingChapter:41
                                    endingChapter:44],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 3" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                  startingChapter:21
                                    endingChapter:23],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 4" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexCorinthians1]
                                  startingChapter:4
                                    endingChapter:6],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 5" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:26
                                    endingChapter:28],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 6" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexRuth]],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 7" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:30
                                    endingChapter:31],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 8" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJob]
                                  startingChapter:25
                                    endingChapter:28],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 9" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexIsaiah]
                                  startingChapter:45
                                    endingChapter:48],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 10" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                  startingChapter:24
                                    endingChapter:25],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 11" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexCorinthians1]
                                  startingChapter:7
                                    endingChapter:9],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 12" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:29
                                    endingChapter:30],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 13" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSamuel1]
                                  startingChapter:1
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 14" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:32
                                    endingChapter:33],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 15" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJob]
                                  startingChapter:29
                                    endingChapter:31],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 16" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexIsaiah]
                                  startingChapter:49
                                    endingChapter:52],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 17" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                       oneChapter:26],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 18" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexCorinthians1]
                                  startingChapter:10
                                    endingChapter:11],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 19" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:31
                                    endingChapter:33],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 20" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSamuel1]
                                  startingChapter:5
                                    endingChapter:12],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 21" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:34
                                    endingChapter:36],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 22" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJob]
                                  startingChapter:32
                                    endingChapter:34],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 23" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexIsaiah]
                                  startingChapter:53
                                    endingChapter:57],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 24" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                  startingChapter:27
                                    endingChapter:28],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 25" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexCorinthians1]
                                  startingChapter:12
                                    endingChapter:14],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 26" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:34
                                    endingChapter:36],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 27" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSamuel1]
                                  startingChapter:13
                                    endingChapter:15],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 28" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                       oneChapter:37],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 29" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJob]
                                  startingChapter:35
                                    endingChapter:36],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 30" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexIsaiah]
                                  startingChapter:58
                                    endingChapter:62],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 31" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMark]
                                  startingChapter:1
                                    endingChapter:3],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 1" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexCorinthians1]
                                  startingChapter:15
                                    endingChapter:16],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 2" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:37
                                    endingChapter:39],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 3" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSamuel1]
                                  startingChapter:16
                                    endingChapter:20],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 4" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:38
                                    endingChapter:39],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 5" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJob]
                                       oneChapter:37],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 6" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexIsaiah]
                                  startingChapter:63
                                    endingChapter:66],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 7" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMark]
                                  startingChapter:4
                                    endingChapter:5],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 8" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexCorinthians2]
                                  startingChapter:1
                                    endingChapter:3],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 9" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:40
                                    endingChapter:42],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 10" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSamuel1]
                                  startingChapter:21
                                    endingChapter:25],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 11" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:40
                                    endingChapter:41],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 12" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJob]
                                       oneChapter:38],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 13" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJeremiah]
                                  startingChapter:1
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 14" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMark]
                                  startingChapter:6
                                    endingChapter:7],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 15" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexCorinthians2]
                                  startingChapter:4
                                    endingChapter:7],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 16" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:43
                                    endingChapter:45],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 17" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSamuel1]
                                  startingChapter:26
                                    endingChapter:31],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 18" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:42
                                    endingChapter:44],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 19" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJob]
                                       oneChapter:39],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 20" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJeremiah]
                                  startingChapter:5
                                    endingChapter:9],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 21" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMark]
                                  startingChapter:8
                                    endingChapter:9],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 22" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexCorinthians2]
                                  startingChapter:8
                                    endingChapter:10],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 23" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:46
                                    endingChapter:47],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 24" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSamuel2]
                                  startingChapter:1
                                    endingChapter:5],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 25" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:45
                                    endingChapter:48],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 26" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJob]
                                  startingChapter:40
                                    endingChapter:42],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 27" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJeremiah]
                                  startingChapter:10
                                    endingChapter:13],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 28" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMark]
                                  startingChapter:10
                                    endingChapter:11],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 29" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexCorinthians2]
                                  startingChapter:11
                                    endingChapter:13],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 30" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:48
                                    endingChapter:50],
                ]],
                [[Reading alloc] initWithDay:@"May 1" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSamuel2]
                                  startingChapter:6
                                    endingChapter:10],
                ]],
                [[Reading alloc] initWithDay:@"May 2" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:49
                                    endingChapter:50],
                ]],
                [[Reading alloc] initWithDay:@"May 3" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                  startingChapter:1
                                    endingChapter:2],
                ]],
                [[Reading alloc] initWithDay:@"May 4" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJeremiah]
                                  startingChapter:14
                                    endingChapter:17],
                ]],
                [[Reading alloc] initWithDay:@"May 5" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMark]
                                  startingChapter:12
                                    endingChapter:13],
                ]],
                [[Reading alloc] initWithDay:@"May 6" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGalatians]
                                  startingChapter:1
                                    endingChapter:3],
                ]],
                [[Reading alloc] initWithDay:@"May 7" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexExodus]
                                  startingChapter:1
                                    endingChapter:2],
                ]],
                [[Reading alloc] initWithDay:@"May 8" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSamuel2]
                                  startingChapter:11
                                    endingChapter:14],
                ]],
                [[Reading alloc] initWithDay:@"May 9" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:51
                                    endingChapter:54],
                ]],
                [[Reading alloc] initWithDay:@"May 10" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                  startingChapter:3
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"May 11" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJeremiah]
                                  startingChapter:18
                                    endingChapter:22],
                ]],
                [[Reading alloc] initWithDay:@"May 12" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMark]
                                  startingChapter:14
                                    endingChapter:16],
                ]],
                [[Reading alloc] initWithDay:@"May 13" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGalatians]
                                  startingChapter:4
                                    endingChapter:6],
                ]],
                [[Reading alloc] initWithDay:@"May 14" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexExodus]
                                  startingChapter:3
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"May 15" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSamuel2]
                                  startingChapter:15
                                    endingChapter:19],
                ]],
                [[Reading alloc] initWithDay:@"May 16" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:55
                                    endingChapter:57],
                ]],
                [[Reading alloc] initWithDay:@"May 17" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                  startingChapter:5
                                    endingChapter:7],
                ]],
                [[Reading alloc] initWithDay:@"May 18" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJeremiah]
                                  startingChapter:23
                                    endingChapter:27],
                ]],
                [[Reading alloc] initWithDay:@"May 19" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLuke]
                                  startingChapter:1
                                    endingChapter:2],
                ]],
                [[Reading alloc] initWithDay:@"May 20" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEphesians]
                                  startingChapter:1
                                    endingChapter:3],
                ]],
                [[Reading alloc] initWithDay:@"May 21" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexExodus]
                                  startingChapter:5
                                    endingChapter:7],
                ]],
                [[Reading alloc] initWithDay:@"May 22" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSamuel2]
                                  startingChapter:20
                                    endingChapter:24],
                ]],
                [[Reading alloc] initWithDay:@"May 23" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:58
                                    endingChapter:60],
                ]],
                [[Reading alloc] initWithDay:@"May 24" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                  startingChapter:8
                                    endingChapter:9],
                ]],
                [[Reading alloc] initWithDay:@"May 25" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJeremiah]
                                  startingChapter:28
                                    endingChapter:31],
                ]],
                [[Reading alloc] initWithDay:@"May 26" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLuke]
                                  startingChapter:3
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"May 27" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEphesians]
                                  startingChapter:4
                                    endingChapter:6],
                ]],
                [[Reading alloc] initWithDay:@"May 28" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexExodus]
                                  startingChapter:8
                                    endingChapter:10],
                ]],
                [[Reading alloc] initWithDay:@"May 29" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings1]
                                  startingChapter:1
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"May 30" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:61
                                    endingChapter:64],
                ]],
                [[Reading alloc] initWithDay:@"May 31" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                       oneChapter:10],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 1" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJeremiah]
                                  startingChapter:32
                                    endingChapter:36],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 2" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLuke]
                                  startingChapter:5
                                    endingChapter:6],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 3" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPhilippians]
                                  startingChapter:1
                                    endingChapter:2],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 4" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexExodus]
                                  startingChapter:11
                                    endingChapter:13],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 5" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings1]
                                  startingChapter:5
                                    endingChapter:7],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 6" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:65
                                    endingChapter:67],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 7" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                       oneChapter:11],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 8" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJeremiah]
                                  startingChapter:37
                                    endingChapter:43],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 9" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLuke]
                                  startingChapter:7
                                    endingChapter:8],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 10" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPhilippians]
                                  startingChapter:3
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 11" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexExodus]
                                  startingChapter:14
                                    endingChapter:16],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 12" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings1]
                                  startingChapter:8
                                    endingChapter:11],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 13" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:68
                                    endingChapter:69],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 14" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                       oneChapter:12],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 15" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJeremiah]
                                  startingChapter:44
                                    endingChapter:48],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 16" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLuke]
                                  startingChapter:9
                                    endingChapter:10],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 17" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexColossians]
                                  startingChapter:1
                                    endingChapter:2],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 18" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexExodus]
                                  startingChapter:17
                                    endingChapter:20],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 19" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings1]
                                  startingChapter:12
                                    endingChapter:16],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 20" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:70
                                    endingChapter:72],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 21" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                       oneChapter:13],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 22" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJeremiah]
                                  startingChapter:49
                                    endingChapter:50],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 23" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLuke]
                                  startingChapter:11
                                    endingChapter:12],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 24" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexColossians]
                                  startingChapter:3
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 25" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexExodus]
                                  startingChapter:21
                                    endingChapter:24],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 26" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings1]
                                  startingChapter:17
                                    endingChapter:20],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 27" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:73
                                    endingChapter:74],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 28" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                       oneChapter:14],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 29" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJeremiah]
                                  startingChapter:51
                                    endingChapter:52],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 30" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLuke]
                                  startingChapter:13
                                    endingChapter:14],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 1" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexThessalonians1]
                                  startingChapter:1
                                    endingChapter:3],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 2" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexExodus]
                                  startingChapter:25
                                    endingChapter:30],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 3" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings1]
                                  startingChapter:21
                                    endingChapter:22],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 4" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:75
                                    endingChapter:77],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 5" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                       oneChapter:15],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 6" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLamentations]],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 7" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLuke]
                                  startingChapter:15
                                    endingChapter:16],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 8" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexThessalonians1]
                                  startingChapter:4
                                    endingChapter:5],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 9" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexExodus]
                                  startingChapter:31
                                    endingChapter:34],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 10" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings2]
                                  startingChapter:1
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 11" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                       oneChapter:78],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 12" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                       oneChapter:16],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 13" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEzekiel]
                                  startingChapter:1
                                    endingChapter:6],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 14" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLuke]
                                  startingChapter:17
                                    endingChapter:18],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 15" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexThessalonians2]],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 16" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexExodus]
                                  startingChapter:35
                                    endingChapter:40],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 17" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings2]
                                  startingChapter:5
                                    endingChapter:8],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 18" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:79
                                    endingChapter:81],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 19" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                       oneChapter:17],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 20" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEzekiel]
                                  startingChapter:7
                                    endingChapter:12],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 21" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLuke]
                                  startingChapter:19
                                    endingChapter:20],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 22" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexTimothy1]
                                  startingChapter:1
                                    endingChapter:3],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 23" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLeviticus]
                                  startingChapter:1
                                    endingChapter:8],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 24" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings2]
                                  startingChapter:9
                                    endingChapter:12],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 25" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:82
                                    endingChapter:85],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 26" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                       oneChapter:18],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 27" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEzekiel]
                                  startingChapter:13
                                    endingChapter:17],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 28" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLuke]
                                  startingChapter:21
                                    endingChapter:22],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 29" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexTimothy1]
                                  startingChapter:4
                                    endingChapter:6],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 30" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLeviticus]
                                  startingChapter:9
                                    endingChapter:15],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 31" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings2]
                                  startingChapter:13
                                    endingChapter:16],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 1" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:86
                                    endingChapter:88],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 2" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                       oneChapter:19],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 3" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEzekiel]
                                  startingChapter:18
                                    endingChapter:21],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 4" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLuke]
                                  startingChapter:23
                                    endingChapter:24],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 5" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexTimothy2]],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 6" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLeviticus]
                                  startingChapter:16
                                    endingChapter:22],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 7" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings2]
                                  startingChapter:17
                                    endingChapter:20],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 8" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                       oneChapter:89],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 9" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                       oneChapter:20],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 10" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEzekiel]
                                  startingChapter:22
                                    endingChapter:25],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 11" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJohn]
                                  startingChapter:1
                                    endingChapter:2],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 12" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexTitus]],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 13" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLeviticus]
                                  startingChapter:23
                                    endingChapter:27],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 14" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings2]
                                  startingChapter:21
                                    endingChapter:25],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 15" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:90
                                    endingChapter:93],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 16" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                       oneChapter:21],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 17" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEzekiel]
                                  startingChapter:26
                                    endingChapter:30],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 18" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJohn]
                                  startingChapter:3
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 19" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPhilemon]],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 20" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNumbers]
                                  startingChapter:1
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 21" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles1]
                                  startingChapter:1
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 22" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:94
                                    endingChapter:96],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 23" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                       oneChapter:22],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 24" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEzekiel]
                                  startingChapter:31
                                    endingChapter:34],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 25" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJohn]
                                  startingChapter:5
                                    endingChapter:6],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 26" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexHebrews]
                                  startingChapter:1
                                    endingChapter:3],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 27" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNumbers]
                                  startingChapter:5
                                    endingChapter:9],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 28" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles1]
                                  startingChapter:5
                                    endingChapter:9],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 29" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:97
                                    endingChapter:101],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 30" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                       oneChapter:23],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 31" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEzekiel]
                                  startingChapter:35
                                    endingChapter:39],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 1" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJohn]
                                  startingChapter:7
                                    endingChapter:8],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 2" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexHebrews]
                                  startingChapter:4
                                    endingChapter:7],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 3" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNumbers]
                                  startingChapter:10
                                    endingChapter:12],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 4" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles1]
                                  startingChapter:10
                                    endingChapter:13],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 5" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:102
                                    endingChapter:103],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 6" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                       oneChapter:24],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 7" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEzekiel]
                                  startingChapter:40
                                    endingChapter:43],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 8" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJohn]
                                  startingChapter:9
                                    endingChapter:10],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 9" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexHebrews]
                                  startingChapter:8
                                    endingChapter:9],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 10" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNumbers]
                                  startingChapter:13
                                    endingChapter:14],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 11" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles1]
                                  startingChapter:14
                                    endingChapter:17],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 12" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:104
                                    endingChapter:105],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 13" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                       oneChapter:25],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 14" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEzekiel]
                                  startingChapter:44
                                    endingChapter:48],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 15" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJohn]
                                  startingChapter:11
                                    endingChapter:12],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 16" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexHebrews]
                                  startingChapter:10
                                    endingChapter:11],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 17" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNumbers]
                                  startingChapter:15
                                    endingChapter:17],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 18" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles1]
                                  startingChapter:18
                                    endingChapter:22],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 19" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                       oneChapter:106],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 20" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                       oneChapter:26],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 21" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexDaniel]
                                  startingChapter:1
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 22" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJohn]
                                  startingChapter:13
                                    endingChapter:14],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 23" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexHebrews]
                                  startingChapter:12
                                    endingChapter:13],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 24" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNumbers]
                                  startingChapter:18
                                    endingChapter:20],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 25" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles1]
                                  startingChapter:23
                                    endingChapter:26],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 26" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:107
                                    endingChapter:108],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 27" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                       oneChapter:27],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 28" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexDaniel]
                                  startingChapter:5
                                    endingChapter:8],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 29" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJohn]
                                  startingChapter:15
                                    endingChapter:16],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 30" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJames]
                                  startingChapter:1
                                    endingChapter:2],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 1" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNumbers]
                                  startingChapter:21
                                    endingChapter:24],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 2" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles1]
                                  startingChapter:27
                                    endingChapter:29],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 3" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:109
                                    endingChapter:113],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 4" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                       oneChapter:28],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 5" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexDaniel]
                                  startingChapter:9
                                    endingChapter:12],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 6" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJohn]
                                  startingChapter:17
                                    endingChapter:19],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 7" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJames]
                                  startingChapter:3
                                    endingChapter:5],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 8" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNumbers]
                                  startingChapter:25
                                    endingChapter:27],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 9" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles2]
                                  startingChapter:1
                                    endingChapter:7],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 10" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:114
                                    endingChapter:118],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 11" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                       oneChapter:29],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 12" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexHosea]
                                  startingChapter:1
                                    endingChapter:7],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 13" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJohn]
                                  startingChapter:20
                                    endingChapter:21],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 14" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPeter1]
                                  startingChapter:1
                                    endingChapter:2],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 15" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNumbers]
                                  startingChapter:28
                                    endingChapter:31],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 16" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles2]
                                  startingChapter:8
                                    endingChapter:12],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 17" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                       oneChapter:119
                                    startingVerse:1
                                      endingVerse:96],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 18" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                       oneChapter:30],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 19" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexHosea]
                                  startingChapter:8
                                    endingChapter:14],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 20" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexActs]
                                  startingChapter:1
                                    endingChapter:2],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 21" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPeter1]
                                  startingChapter:3
                                    endingChapter:5],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 22" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNumbers]
                                  startingChapter:32
                                    endingChapter:36],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 23" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles2]
                                  startingChapter:13
                                    endingChapter:20],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 24" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                       oneChapter:119
                                    startingVerse:97
                                      endingVerse:176],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 25" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                       oneChapter:31],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 26" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJoel]],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 27" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexActs]
                                  startingChapter:3
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 28" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPeter2]],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 29" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexDeuteronomy]
                                  startingChapter:1
                                    endingChapter:3],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 30" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles2]
                                  startingChapter:21
                                    endingChapter:26],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 31" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:120
                                    endingChapter:124],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 1" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEcclesiastes]
                                  startingChapter:1
                                    endingChapter:2],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 2" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexAmos]
                                  startingChapter:1
                                    endingChapter:5],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 3" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexActs]
                                  startingChapter:5
                                    endingChapter:7],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 4" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJohn1]
                                  startingChapter:1
                                    endingChapter:3],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 5" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexDeuteronomy]
                                  startingChapter:4
                                    endingChapter:5],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 6" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles2]
                                  startingChapter:27
                                    endingChapter:32],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 7" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:125
                                    endingChapter:129],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 8" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEcclesiastes]
                                  startingChapter:3
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 9" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexAmos]
                                  startingChapter:6
                                    endingChapter:9],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 10" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexActs]
                                  startingChapter:8
                                    endingChapter:9],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 11" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJohn1]
                                  startingChapter:4
                                    endingChapter:5],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 12" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexDeuteronomy]
                                  startingChapter:6
                                    endingChapter:9],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 13" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles2]
                                  startingChapter:33
                                    endingChapter:36],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 14" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:130
                                    endingChapter:132],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 15" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEcclesiastes]
                                  startingChapter:5
                                    endingChapter:6],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 16" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexObadiah]],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJonah]],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 17" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexActs]
                                  startingChapter:10
                                    endingChapter:12],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 18" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJohn2]],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJohn3]],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 19" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexDeuteronomy]
                                  startingChapter:10
                                    endingChapter:13],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 20" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEzra]
                                  startingChapter:1
                                    endingChapter:6],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 21" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:133
                                    endingChapter:135],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 22" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEcclesiastes]
                                  startingChapter:7
                                    endingChapter:8],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 23" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMicah]],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 24" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexActs]
                                  startingChapter:13
                                    endingChapter:14],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 25" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJude]],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 26" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexDeuteronomy]
                                  startingChapter:14
                                    endingChapter:17],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 27" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEzra]
                                  startingChapter:7
                                    endingChapter:10],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 28" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:136
                                    endingChapter:138],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 29" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEcclesiastes]
                                  startingChapter:9
                                    endingChapter:10],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 30" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNahum]],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexHabakkuk]],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 1" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexActs]
                                  startingChapter:15
                                    endingChapter:17],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 2" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexRevelation]
                                  startingChapter:1
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 3" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexDeuteronomy]
                                  startingChapter:18
                                    endingChapter:22],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 4" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNehemiah]
                                  startingChapter:1
                                    endingChapter:5],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 5" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:139
                                    endingChapter:141],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 6" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEcclesiastes]
                                  startingChapter:11
                                    endingChapter:12],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 7" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexZephaniah]],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexHaggai]],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 8" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexActs]
                                  startingChapter:18
                                    endingChapter:20],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 9" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexRevelation]
                                  startingChapter:5
                                    endingChapter:9],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 10" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexDeuteronomy]
                                  startingChapter:23
                                    endingChapter:27],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 11" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNehemiah]
                                  startingChapter:6
                                    endingChapter:10],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 12" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:142
                                    endingChapter:144],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 13" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSongOfSolomon]
                                  startingChapter:1
                                    endingChapter:2],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 14" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexZechariah]
                                  startingChapter:1
                                    endingChapter:8],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 15" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexActs]
                                  startingChapter:21
                                    endingChapter:23],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 16" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexRevelation]
                                  startingChapter:10
                                    endingChapter:14],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 17" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexDeuteronomy]
                                  startingChapter:28
                                    endingChapter:29],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 18" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNehemiah]
                                  startingChapter:11
                                    endingChapter:13],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 19" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:145
                                    endingChapter:147],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 20" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSongOfSolomon]
                                  startingChapter:3
                                    endingChapter:5],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 21" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexZechariah]
                                  startingChapter:9
                                    endingChapter:14],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 22" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexActs]
                                  startingChapter:24
                                    endingChapter:26],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 23" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexRevelation]
                                  startingChapter:15
                                    endingChapter:19],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 24" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexDeuteronomy]
                                  startingChapter:30
                                    endingChapter:31],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 25" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEsther]],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 26" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:148
                                    endingChapter:150],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 27" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSongOfSolomon]
                                  startingChapter:6
                                    endingChapter:8],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 28" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMalachi]],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 29" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexActs]
                                  startingChapter:27
                                    endingChapter:28],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 30" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexRevelation]
                                  startingChapter:20
                                    endingChapter:22],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 31" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexDeuteronomy]
                                  startingChapter:32
                                    endingChapter:34],
                ]],
            ];
#pragma mark Sequential
        case BRReadingTypeSequential:
            return @[
                [[Reading alloc] initWithDay:@"Jan. 1" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:1
                                    endingChapter:3],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 2" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:4
                                    endingChapter:7],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 3" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:8
                                    endingChapter:11],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 4" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:12
                                    endingChapter:15],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 5" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:16
                                    endingChapter:19],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 6" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:20
                                    endingChapter:23],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 7" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:24
                                    endingChapter:26],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 8" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:27
                                    endingChapter:28],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 9" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:29
                                    endingChapter:30],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 10" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:31
                                    endingChapter:33],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 11" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:34
                                    endingChapter:36],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 12" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:37
                                    endingChapter:39],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 13" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:40
                                    endingChapter:41],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 14" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:42
                                    endingChapter:44],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 15" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:45
                                    endingChapter:47],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 16" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:48
                                    endingChapter:50],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 17" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexExodus]
                                  startingChapter:1
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 18" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexExodus]
                                  startingChapter:5
                                    endingChapter:7],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 19" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexExodus]
                                  startingChapter:8
                                    endingChapter:10],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 20" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexExodus]
                                  startingChapter:11
                                    endingChapter:12],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 21" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexExodus]
                                  startingChapter:13
                                    endingChapter:15],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 22" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexExodus]
                                  startingChapter:16
                                    endingChapter:18],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 23" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexExodus]
                                  startingChapter:19
                                    endingChapter:23],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 24" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexExodus]
                                  startingChapter:24
                                    endingChapter:27],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 25" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexExodus]
                                  startingChapter:28
                                    endingChapter:30],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 26" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexExodus]
                                  startingChapter:31
                                    endingChapter:34],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 27" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexExodus]
                                  startingChapter:35
                                    endingChapter:37],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 28" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexExodus]
                                  startingChapter:38
                                    endingChapter:40],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 29" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLeviticus]
                                  startingChapter:1
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 30" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLeviticus]
                                  startingChapter:5
                                    endingChapter:7],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 31" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLeviticus]
                                  startingChapter:8
                                    endingChapter:11],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 1" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLeviticus]
                                  startingChapter:12
                                    endingChapter:14],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 2" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLeviticus]
                                  startingChapter:15
                                    endingChapter:18],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 3" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLeviticus]
                                  startingChapter:19
                                    endingChapter:22],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 4" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLeviticus]
                                  startingChapter:23
                                    endingChapter:25],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 5" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLeviticus]
                                  startingChapter:26
                                    endingChapter:27],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 6" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNumbers]
                                  startingChapter:1
                                    endingChapter:3],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 7" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNumbers]
                                  startingChapter:4
                                    endingChapter:6],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 8" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNumbers]
                                  startingChapter:7
                                    endingChapter:8],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 9" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNumbers]
                                  startingChapter:9
                                    endingChapter:11],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 10" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNumbers]
                                  startingChapter:12
                                    endingChapter:14],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 11" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNumbers]
                                  startingChapter:15
                                    endingChapter:18],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 12" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNumbers]
                                  startingChapter:19
                                    endingChapter:21],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 13" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNumbers]
                                  startingChapter:22
                                    endingChapter:24],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 14" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNumbers]
                                  startingChapter:25
                                    endingChapter:27],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 15" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNumbers]
                                  startingChapter:28
                                    endingChapter:31],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 16" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNumbers]
                                  startingChapter:32
                                    endingChapter:36],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 17" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexDeuteronomy]
                                  startingChapter:1
                                    endingChapter:3],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 18" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexDeuteronomy]
                                  startingChapter:4
                                    endingChapter:6],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 19" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexDeuteronomy]
                                  startingChapter:7
                                    endingChapter:10],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 20" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexDeuteronomy]
                                  startingChapter:11
                                    endingChapter:14],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 21" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexDeuteronomy]
                                  startingChapter:15
                                    endingChapter:18],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 22" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexDeuteronomy]
                                  startingChapter:19
                                    endingChapter:22],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 23" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexDeuteronomy]
                                  startingChapter:23
                                    endingChapter:27],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 24" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexDeuteronomy]
                                  startingChapter:28
                                    endingChapter:30],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 25" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexDeuteronomy]
                                  startingChapter:31
                                    endingChapter:34],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 26" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJoshua]
                                  startingChapter:1
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 27" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJoshua]
                                  startingChapter:5
                                    endingChapter:8],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 28" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJoshua]
                                  startingChapter:9
                                    endingChapter:12],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 1" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJoshua]
                                  startingChapter:13
                                    endingChapter:17],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 2" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJoshua]
                                  startingChapter:18
                                    endingChapter:21],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 3" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJoshua]
                                  startingChapter:22
                                    endingChapter:24],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 4" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJudges]
                                  startingChapter:1
                                    endingChapter:3],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 5" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJudges]
                                  startingChapter:4
                                    endingChapter:5],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 6" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJudges]
                                  startingChapter:6
                                    endingChapter:8],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 7" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJudges]
                                  startingChapter:9
                                    endingChapter:12],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 8" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJudges]
                                  startingChapter:13
                                    endingChapter:16],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 9" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJudges]
                                  startingChapter:17
                                    endingChapter:21],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 10" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexRuth]],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 11" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSamuel1]
                                  startingChapter:1
                                    endingChapter:3],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 12" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSamuel1]
                                  startingChapter:4
                                    endingChapter:7],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 13" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSamuel1]
                                  startingChapter:8
                                    endingChapter:11],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 14" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSamuel1]
                                  startingChapter:12
                                    endingChapter:14],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 15" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSamuel1]
                                  startingChapter:15
                                    endingChapter:17],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 16" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSamuel1]
                                  startingChapter:18
                                    endingChapter:20],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 17" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSamuel1]
                                  startingChapter:21
                                    endingChapter:24],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 18" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSamuel1]
                                  startingChapter:25
                                    endingChapter:27],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 19" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSamuel1]
                                  startingChapter:28
                                    endingChapter:31],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 20" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSamuel2]
                                  startingChapter:1
                                    endingChapter:3],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 21" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSamuel2]
                                  startingChapter:4
                                    endingChapter:7],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 22" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSamuel2]
                                  startingChapter:8
                                    endingChapter:12],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 23" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSamuel2]
                                  startingChapter:13
                                    endingChapter:15],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 24" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSamuel2]
                                  startingChapter:16
                                    endingChapter:18],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 25" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSamuel2]
                                  startingChapter:19
                                    endingChapter:21],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 26" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSamuel2]
                                  startingChapter:22
                                    endingChapter:24],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 27" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings1]
                                  startingChapter:1
                                    endingChapter:2],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 28" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings1]
                                  startingChapter:3
                                    endingChapter:6],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 29" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings1]
                                  startingChapter:7
                                    endingChapter:8],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 30" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings1]
                                  startingChapter:9
                                    endingChapter:11],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 31" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings1]
                                  startingChapter:12
                                    endingChapter:14],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 1" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings1]
                                  startingChapter:15
                                    endingChapter:19],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 2" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings1]
                                  startingChapter:20
                                    endingChapter:22],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 3" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings2]
                                  startingChapter:1
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 4" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings2]
                                  startingChapter:5
                                    endingChapter:8],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 5" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings2]
                                  startingChapter:9
                                    endingChapter:12],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 6" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings2]
                                  startingChapter:13
                                    endingChapter:15],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 7" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings2]
                                  startingChapter:16
                                    endingChapter:20],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 8" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings2]
                                  startingChapter:21
                                    endingChapter:25],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 9" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles1]
                                  startingChapter:1
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 10" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles1]
                                  startingChapter:5
                                    endingChapter:7],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 11" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles1]
                                  startingChapter:8
                                    endingChapter:12],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 12" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles1]
                                  startingChapter:13
                                    endingChapter:17],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 13" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles1]
                                  startingChapter:18
                                    endingChapter:22],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 14" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles1]
                                  startingChapter:23
                                    endingChapter:26],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 15" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles1]
                                  startingChapter:27
                                    endingChapter:29],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 16" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles2]
                                  startingChapter:1
                                    endingChapter:5],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 17" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles2]
                                  startingChapter:6
                                    endingChapter:8],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 18" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles2]
                                  startingChapter:9
                                    endingChapter:12],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 19" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles2]
                                  startingChapter:13
                                    endingChapter:17],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 20" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles2]
                                  startingChapter:18
                                    endingChapter:21],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 21" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles2]
                                  startingChapter:22
                                    endingChapter:25],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 22" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles2]
                                  startingChapter:26
                                    endingChapter:29],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 23" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles2]
                                  startingChapter:30
                                    endingChapter:32],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 24" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles2]
                                  startingChapter:33
                                    endingChapter:36],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 25" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEzra]
                                  startingChapter:1
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 26" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEzra]
                                  startingChapter:5
                                    endingChapter:7],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 27" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEzra]
                                  startingChapter:8
                                    endingChapter:10],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 28" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNehemiah]
                                  startingChapter:1
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 29" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNehemiah]
                                  startingChapter:5
                                    endingChapter:7],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 30" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNehemiah]
                                  startingChapter:8
                                    endingChapter:10],
                ]],
                [[Reading alloc] initWithDay:@"May 1" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNehemiah]
                                  startingChapter:11
                                    endingChapter:13],
                ]],
                [[Reading alloc] initWithDay:@"May 2" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEsther]
                                  startingChapter:1
                                    endingChapter:5],
                ]],
                [[Reading alloc] initWithDay:@"May 3" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEsther]
                                  startingChapter:6
                                    endingChapter:10],
                ]],
                [[Reading alloc] initWithDay:@"May 4" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJob]
                                  startingChapter:1
                                    endingChapter:5],
                ]],
                [[Reading alloc] initWithDay:@"May 5" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJob]
                                  startingChapter:6
                                    endingChapter:10],
                ]],
                [[Reading alloc] initWithDay:@"May 6" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJob]
                                  startingChapter:11
                                    endingChapter:15],
                ]],
                [[Reading alloc] initWithDay:@"May 7" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJob]
                                  startingChapter:16
                                    endingChapter:20],
                ]],
                [[Reading alloc] initWithDay:@"May 8" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJob]
                                  startingChapter:21
                                    endingChapter:25],
                ]],
                [[Reading alloc] initWithDay:@"May 9" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJob]
                                  startingChapter:26
                                    endingChapter:31],
                ]],
                [[Reading alloc] initWithDay:@"May 10" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJob]
                                  startingChapter:32
                                    endingChapter:37],
                ]],
                [[Reading alloc] initWithDay:@"May 11" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJob]
                                  startingChapter:38
                                    endingChapter:42],
                ]],
                [[Reading alloc] initWithDay:@"May 12" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:1
                                    endingChapter:5],
                ]],
                [[Reading alloc] initWithDay:@"May 13" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:6
                                    endingChapter:9],
                ]],
                [[Reading alloc] initWithDay:@"May 14" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:10
                                    endingChapter:16],
                ]],
                [[Reading alloc] initWithDay:@"May 15" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:17
                                    endingChapter:18],
                ]],
                [[Reading alloc] initWithDay:@"May 16" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:19
                                    endingChapter:22],
                ]],
                [[Reading alloc] initWithDay:@"May 17" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:23
                                    endingChapter:27],
                ]],
                [[Reading alloc] initWithDay:@"May 18" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:28
                                    endingChapter:31],
                ]],
                [[Reading alloc] initWithDay:@"May 19" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:32
                                    endingChapter:35],
                ]],
                [[Reading alloc] initWithDay:@"May 20" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:36
                                    endingChapter:38],
                ]],
                [[Reading alloc] initWithDay:@"May 21" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:39
                                    endingChapter:41],
                ]],
                [[Reading alloc] initWithDay:@"May 22" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:42
                                    endingChapter:45],
                ]],
                [[Reading alloc] initWithDay:@"May 23" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:46
                                    endingChapter:49],
                ]],
                [[Reading alloc] initWithDay:@"May 24" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:50
                                    endingChapter:53],
                ]],
                [[Reading alloc] initWithDay:@"May 25" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:54
                                    endingChapter:56],
                ]],
                [[Reading alloc] initWithDay:@"May 26" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:57
                                    endingChapter:59],
                ]],
                [[Reading alloc] initWithDay:@"May 27" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:60
                                    endingChapter:63],
                ]],
                [[Reading alloc] initWithDay:@"May 28" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:64
                                    endingChapter:67],
                ]],
                [[Reading alloc] initWithDay:@"May 29" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:68
                                    endingChapter:69],
                ]],
                [[Reading alloc] initWithDay:@"May 30" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:70
                                    endingChapter:72],
                ]],
                [[Reading alloc] initWithDay:@"May 31" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:73
                                    endingChapter:74],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 1" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:75
                                    endingChapter:77],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 2" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                       oneChapter:78],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 3" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:79
                                    endingChapter:82],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 4" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:83
                                    endingChapter:86],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 5" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:87
                                    endingChapter:88],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 6" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                       oneChapter:89],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 7" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:90
                                    endingChapter:93],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 8" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:94
                                    endingChapter:99],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 9" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:100
                                    endingChapter:103],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 10" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:104
                                    endingChapter:105],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 11" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                       oneChapter:106],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 12" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:107
                                    endingChapter:109],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 13" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:110
                                    endingChapter:115],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 14" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:116
                                    endingChapter:118],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 15" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                       oneChapter:119],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 16" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:120
                                    endingChapter:131],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 17" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:132
                                    endingChapter:137],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 18" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:138
                                    endingChapter:141],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 19" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:142
                                    endingChapter:145],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 20" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:146
                                    endingChapter:150],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 21" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                  startingChapter:1
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 22" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                  startingChapter:5
                                    endingChapter:9],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 23" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                  startingChapter:10
                                    endingChapter:11],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 24" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                  startingChapter:12
                                    endingChapter:13],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 25" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                  startingChapter:14
                                    endingChapter:15],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 26" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                  startingChapter:16
                                    endingChapter:17],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 27" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                  startingChapter:18
                                    endingChapter:19],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 28" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                  startingChapter:20
                                    endingChapter:21],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 29" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                  startingChapter:22
                                    endingChapter:24],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 30" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                  startingChapter:25
                                    endingChapter:26],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 1" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                  startingChapter:27
                                    endingChapter:28],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 2" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                  startingChapter:29
                                    endingChapter:31],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 3" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEcclesiastes]
                                  startingChapter:1
                                    endingChapter:3],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 4" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEcclesiastes]
                                  startingChapter:4
                                    endingChapter:8],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 5" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEcclesiastes]
                                  startingChapter:9
                                    endingChapter:12],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 6" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSongOfSolomon]
                                  startingChapter:1
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 7" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSongOfSolomon]
                                  startingChapter:5
                                    endingChapter:8],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 8" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexIsaiah]
                                  startingChapter:1
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 9" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexIsaiah]
                                  startingChapter:5
                                    endingChapter:7],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 10" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexIsaiah]
                                  startingChapter:8
                                    endingChapter:11],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 11" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexIsaiah]
                                  startingChapter:12
                                    endingChapter:17],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 12" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexIsaiah]
                                  startingChapter:18
                                    endingChapter:24],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 13" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexIsaiah]
                                  startingChapter:25
                                    endingChapter:29],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 14" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexIsaiah]
                                  startingChapter:30
                                    endingChapter:35],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 15" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexIsaiah]
                                  startingChapter:36
                                    endingChapter:40],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 16" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexIsaiah]
                                  startingChapter:41
                                    endingChapter:44],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 17" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexIsaiah]
                                  startingChapter:45
                                    endingChapter:49],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 18" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexIsaiah]
                                  startingChapter:50
                                    endingChapter:55],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 19" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexIsaiah]
                                  startingChapter:56
                                    endingChapter:61],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 20" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexIsaiah]
                                  startingChapter:62
                                    endingChapter:66],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 21" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJeremiah]
                                  startingChapter:1
                                    endingChapter:3],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 22" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJeremiah]
                                  startingChapter:4
                                    endingChapter:6],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 23" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJeremiah]
                                  startingChapter:7
                                    endingChapter:10],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 24" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJeremiah]
                                  startingChapter:11
                                    endingChapter:15],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 25" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJeremiah]
                                  startingChapter:16
                                    endingChapter:20],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 26" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJeremiah]
                                  startingChapter:21
                                    endingChapter:25],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 27" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJeremiah]
                                  startingChapter:26
                                    endingChapter:30],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 28" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJeremiah]
                                  startingChapter:31
                                    endingChapter:33],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 29" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJeremiah]
                                  startingChapter:34
                                    endingChapter:39],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 30" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJeremiah]
                                  startingChapter:40
                                    endingChapter:46],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 31" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJeremiah]
                                  startingChapter:47
                                    endingChapter:49],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 1" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJeremiah]
                                  startingChapter:50
                                    endingChapter:52],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 2" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLamentations]],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 3" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEzekiel]
                                  startingChapter:1
                                    endingChapter:7],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 4" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEzekiel]
                                  startingChapter:8
                                    endingChapter:15],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 5" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEzekiel]
                                  startingChapter:16
                                    endingChapter:19],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 6" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEzekiel]
                                  startingChapter:20
                                    endingChapter:23],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 7" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEzekiel]
                                  startingChapter:24
                                    endingChapter:28],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 8" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEzekiel]
                                  startingChapter:29
                                    endingChapter:33],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 9" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEzekiel]
                                  startingChapter:34
                                    endingChapter:39],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 10" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEzekiel]
                                  startingChapter:40
                                    endingChapter:43],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 11" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEzekiel]
                                  startingChapter:44
                                    endingChapter:48],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 12" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexDaniel]
                                  startingChapter:1
                                    endingChapter:3],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 13" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexDaniel]
                                  startingChapter:4
                                    endingChapter:6],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 14" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexDaniel]
                                  startingChapter:7
                                    endingChapter:9],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 15" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexDaniel]
                                  startingChapter:10
                                    endingChapter:12],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 16" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexHosea]
                                  startingChapter:1
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 17" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexHosea]
                                  startingChapter:5
                                    endingChapter:9],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 18" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexHosea]
                                  startingChapter:10
                                    endingChapter:14],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 19" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJoel]],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 20" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexAmos]
                                  startingChapter:1
                                    endingChapter:5],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 21" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexAmos]
                                  startingChapter:6
                                    endingChapter:9],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 22" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexObadiah]],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJonah]],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 23" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMicah]
                                  startingChapter:1
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 24" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMicah]
                                  startingChapter:5
                                    endingChapter:7],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 25" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNahum]],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 26" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexHabakkuk]],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 27" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexZephaniah]],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexHaggai]],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 28" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexZechariah]
                                  startingChapter:1
                                    endingChapter:6],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 29" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexZechariah]
                                  startingChapter:7
                                    endingChapter:10],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 30" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexZechariah]
                                  startingChapter:11
                                    endingChapter:14],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 31" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMalachi]],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 1" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                  startingChapter:1
                                    endingChapter:2],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 2" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                  startingChapter:3
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 3" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                  startingChapter:5
                                    endingChapter:7],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 4" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                  startingChapter:8
                                    endingChapter:9],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 5" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                  startingChapter:10
                                    endingChapter:11],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 6" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                  startingChapter:12
                                    endingChapter:13],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 7" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                  startingChapter:14
                                    endingChapter:15],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 8" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                  startingChapter:16
                                    endingChapter:17],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 9" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                  startingChapter:19
                                    endingChapter:20],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 10" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                  startingChapter:21
                                    endingChapter:22],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 11" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                  startingChapter:23
                                    endingChapter:25],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 12" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                  startingChapter:26
                                    endingChapter:28],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 13" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMark]
                                  startingChapter:1
                                    endingChapter:2],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 14" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMark]
                                  startingChapter:3
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 15" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMark]
                                  startingChapter:5
                                    endingChapter:6],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 16" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMark]
                                  startingChapter:7
                                    endingChapter:8],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 17" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMark]
                                  startingChapter:9
                                    endingChapter:10],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 18" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMark]
                                  startingChapter:11
                                    endingChapter:12],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 19" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMark]
                                  startingChapter:13
                                    endingChapter:14],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 20" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMark]
                                  startingChapter:15
                                    endingChapter:16],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 21" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLuke]
                                       oneChapter:1],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 22" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLuke]
                                       oneChapter:2],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 23" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLuke]
                                  startingChapter:3
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 24" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLuke]
                                  startingChapter:5
                                    endingChapter:6],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 25" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLuke]
                                  startingChapter:7
                                    endingChapter:8],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 26" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLuke]
                                  startingChapter:9
                                    endingChapter:10],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 27" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLuke]
                                       oneChapter:11],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 28" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLuke]
                                       oneChapter:12],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 29" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLuke]
                                  startingChapter:13
                                    endingChapter:14],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 30" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLuke]
                                  startingChapter:15
                                    endingChapter:16],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 1" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLuke]
                                  startingChapter:17
                                    endingChapter:18],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 2" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLuke]
                                  startingChapter:19
                                    endingChapter:20],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 3" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLuke]
                                  startingChapter:21
                                    endingChapter:22],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 4" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLuke]
                                  startingChapter:23
                                    endingChapter:24],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 5" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJohn]
                                  startingChapter:1
                                    endingChapter:2],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 6" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJohn]
                                  startingChapter:3
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 7" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJohn]
                                  startingChapter:5
                                    endingChapter:6],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 8" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJohn]
                                  startingChapter:7
                                    endingChapter:8],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 9" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJohn]
                                  startingChapter:9
                                    endingChapter:10],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 10" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJohn]
                                  startingChapter:11
                                    endingChapter:12],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 11" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJohn]
                                  startingChapter:13
                                    endingChapter:14],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 12" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJohn]
                                  startingChapter:15
                                    endingChapter:17],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 13" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJohn]
                                  startingChapter:18
                                    endingChapter:19],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 14" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJohn]
                                  startingChapter:20
                                    endingChapter:21],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 15" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexActs]
                                  startingChapter:1
                                    endingChapter:2],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 16" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexActs]
                                  startingChapter:3
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 17" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexActs]
                                  startingChapter:5
                                    endingChapter:6],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 18" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexActs]
                                       oneChapter:7],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 19" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexActs]
                                  startingChapter:8
                                    endingChapter:9],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 20" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexActs]
                                       oneChapter:10],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 21" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexActs]
                                  startingChapter:11
                                    endingChapter:12],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 22" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexActs]
                                  startingChapter:13
                                    endingChapter:14],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 23" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexActs]
                                  startingChapter:15
                                    endingChapter:16],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 24" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexActs]
                                  startingChapter:17
                                    endingChapter:18],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 25" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexActs]
                                  startingChapter:19
                                    endingChapter:20],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 26" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexActs]
                                  startingChapter:21
                                    endingChapter:23],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 27" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexActs]
                                  startingChapter:24
                                    endingChapter:26],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 28" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexActs]
                                  startingChapter:27
                                    endingChapter:28],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 29" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexRomans]
                                  startingChapter:1
                                    endingChapter:2],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 30" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexRomans]
                                  startingChapter:3
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 31" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexRomans]
                                  startingChapter:5
                                    endingChapter:6],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 1" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexRomans]
                                  startingChapter:7
                                    endingChapter:8],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 2" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexRomans]
                                  startingChapter:9
                                    endingChapter:10],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 3" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexRomans]
                                  startingChapter:11
                                    endingChapter:14],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 4" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexRomans]
                                  startingChapter:15
                                    endingChapter:16],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 5" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexCorinthians1]
                                  startingChapter:1
                                    endingChapter:2],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 6" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexCorinthians1]
                                  startingChapter:3
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 7" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexCorinthians1]
                                  startingChapter:5
                                    endingChapter:6],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 8" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexCorinthians1]
                                  startingChapter:7
                                    endingChapter:8],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 9" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexCorinthians1]
                                  startingChapter:9
                                    endingChapter:10],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 10" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexCorinthians1]
                                  startingChapter:11
                                    endingChapter:12],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 11" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexCorinthians1]
                                  startingChapter:13
                                    endingChapter:14],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 12" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexCorinthians1]
                                  startingChapter:15
                                    endingChapter:16],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 13" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexCorinthians2]
                                  startingChapter:1
                                    endingChapter:2],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 14" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexCorinthians2]
                                  startingChapter:3
                                    endingChapter:5],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 15" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexCorinthians2]
                                  startingChapter:6
                                    endingChapter:7],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 16" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexCorinthians2]
                                  startingChapter:8
                                    endingChapter:9],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 17" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexCorinthians2]
                                  startingChapter:10
                                    endingChapter:11],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 18" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexCorinthians2]
                                  startingChapter:12
                                    endingChapter:13],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 19" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGalatians]
                                  startingChapter:1
                                    endingChapter:2],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 20" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGalatians]
                                  startingChapter:3
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 21" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGalatians]
                                  startingChapter:5
                                    endingChapter:6],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 22" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEphesians]
                                  startingChapter:1
                                    endingChapter:2],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 23" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEphesians]
                                  startingChapter:3
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 24" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEphesians]
                                  startingChapter:5
                                    endingChapter:6],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 25" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPhilippians]
                                  startingChapter:1
                                    endingChapter:2],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 26" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPhilippians]
                                  startingChapter:3
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 27" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexColossians]
                                  startingChapter:1
                                    endingChapter:2],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 28" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexColossians]
                                  startingChapter:3
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 29" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexThessalonians1]
                                  startingChapter:1
                                    endingChapter:3],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 30" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexThessalonians1]
                                  startingChapter:4
                                    endingChapter:5],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 1" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexThessalonians2]],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 2" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexTimothy1]
                                  startingChapter:1
                                    endingChapter:3],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 3" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexTimothy1]
                                  startingChapter:4
                                    endingChapter:6],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 4" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexTimothy2]
                                  startingChapter:1
                                    endingChapter:2],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 5" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexTimothy1]
                                  startingChapter:3
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 6" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexTitus]],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 7" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPhilemon]],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 8" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexHebrews]
                                  startingChapter:1
                                    endingChapter:2],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 9" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexHebrews]
                                  startingChapter:3
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 10" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexHebrews]
                                  startingChapter:5
                                    endingChapter:7],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 11" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexHebrews]
                                  startingChapter:8
                                    endingChapter:9],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 12" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexHebrews]
                                  startingChapter:10
                                    endingChapter:11],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 13" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexHebrews]
                                  startingChapter:12
                                    endingChapter:13],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 14" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJames]
                                  startingChapter:1
                                    endingChapter:2],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 15" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJames]
                                  startingChapter:3
                                    endingChapter:5],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 16" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPeter1]
                                  startingChapter:1
                                    endingChapter:3],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 17" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPeter1]
                                  startingChapter:4
                                    endingChapter:5],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 18" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPeter2]],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 19" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJohn1]
                                  startingChapter:1
                                    endingChapter:2],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 20" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJohn1]
                                  startingChapter:3
                                    endingChapter:5],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 21" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJohn2]],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJohn3]],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 22" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJude]],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 23" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexRevelation]
                                  startingChapter:1
                                    endingChapter:3],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 24" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexRevelation]
                                  startingChapter:4
                                    endingChapter:6],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 25" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexRevelation]
                                  startingChapter:7
                                    endingChapter:9],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 26" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexRevelation]
                                  startingChapter:10
                                    endingChapter:11],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 27" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexRevelation]
                                  startingChapter:12
                                    endingChapter:13],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 28" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexRevelation]
                                  startingChapter:14
                                    endingChapter:15],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 29" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexRevelation]
                                  startingChapter:16
                                    endingChapter:17],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 30" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexRevelation]
                                  startingChapter:18
                                    endingChapter:20],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 31" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexRevelation]
                                  startingChapter:21
                                    endingChapter:22],
                ]],
            ];
        case BRReadingTypeChronological:
            return @[
                [[Reading alloc] initWithDay:@"Jan. 1" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:1
                                    endingChapter:3],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 2" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:4
                                    endingChapter:7],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 3" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:8
                                    endingChapter:11],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 4" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJob]
                                  startingChapter:1
                                    endingChapter:5],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 5" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJob]
                                  startingChapter:6
                                    endingChapter:9],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 6" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJob]
                                  startingChapter:10
                                    endingChapter:13],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 7" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJob]
                                  startingChapter:14
                                    endingChapter:16],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 8" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJob]
                                  startingChapter:17
                                    endingChapter:20],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 9" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJob]
                                  startingChapter:21
                                    endingChapter:23],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 10" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJob]
                                  startingChapter:24
                                    endingChapter:28],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 11" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJob]
                                  startingChapter:29
                                    endingChapter:31],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 12" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJob]
                                  startingChapter:33
                                    endingChapter:34],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 13" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJob]
                                  startingChapter:35
                                    endingChapter:37],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 14" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJob]
                                  startingChapter:38
                                    endingChapter:39],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 15" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJob]
                                  startingChapter:40
                                    endingChapter:42],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 16" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:12
                                    endingChapter:15],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 17" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:16
                                    endingChapter:18],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 18" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:19
                                    endingChapter:21],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 19" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:22
                                    endingChapter:24],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 20" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:25
                                    endingChapter:26],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 21" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:27
                                    endingChapter:29],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 22" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:30
                                    endingChapter:31],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 23" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:32
                                    endingChapter:34],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 24" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:35
                                    endingChapter:37],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 25" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:38
                                    endingChapter:40],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 26" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:41
                                    endingChapter:42],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 27" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:43
                                    endingChapter:45],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 28" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:46
                                    endingChapter:47],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 29" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGenesis]
                                  startingChapter:48
                                    endingChapter:50],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 30" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexExodus]
                                  startingChapter:1
                                    endingChapter:3],
                ]],
                [[Reading alloc] initWithDay:@"Jan. 31" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexExodus]
                                  startingChapter:4
                                    endingChapter:6],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 1" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexExodus]
                                  startingChapter:7
                                    endingChapter:9],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 2" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexExodus]
                                  startingChapter:10
                                    endingChapter:12],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 3" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexExodus]
                                  startingChapter:13
                                    endingChapter:15],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 4" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexExodus]
                                  startingChapter:16
                                    endingChapter:18],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 5" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexExodus]
                                  startingChapter:19
                                    endingChapter:21],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 6" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexExodus]
                                  startingChapter:22
                                    endingChapter:24],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 7" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexExodus]
                                  startingChapter:25
                                    endingChapter:27],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 8" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexExodus]
                                  startingChapter:28
                                    endingChapter:29],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 9" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexExodus]
                                  startingChapter:30
                                    endingChapter:32],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 10" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexExodus]
                                  startingChapter:33
                                    endingChapter:35],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 11" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexExodus]
                                  startingChapter:36
                                    endingChapter:38],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 12" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexExodus]
                                  startingChapter:39
                                    endingChapter:40],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 13" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLeviticus]
                                  startingChapter:1
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 14" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLeviticus]
                                  startingChapter:5
                                    endingChapter:7],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 15" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLeviticus]
                                  startingChapter:8
                                    endingChapter:10],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 16" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLeviticus]
                                  startingChapter:11
                                    endingChapter:13],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 17" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLeviticus]
                                  startingChapter:14
                                    endingChapter:15],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 18" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLeviticus]
                                  startingChapter:16
                                    endingChapter:18],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 19" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLeviticus]
                                  startingChapter:19
                                    endingChapter:21],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 20" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLeviticus]
                                  startingChapter:22
                                    endingChapter:23],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 21" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLeviticus]
                                  startingChapter:24
                                    endingChapter:25],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 22" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLeviticus]
                                  startingChapter:26
                                    endingChapter:27],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 23" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNumbers]
                                  startingChapter:1
                                    endingChapter:2],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 24" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNumbers]
                                  startingChapter:3
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 25" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNumbers]
                                  startingChapter:5
                                    endingChapter:6],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 26" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNumbers]
                                       oneChapter:7],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 27" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNumbers]
                                  startingChapter:8
                                    endingChapter:10],
                ]],
                [[Reading alloc] initWithDay:@"Feb. 28" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNumbers]
                                  startingChapter:11
                                    endingChapter:13],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 1" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNumbers]
                                  startingChapter:14
                                    endingChapter:15],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                       oneChapter:90],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 2" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNumbers]
                                  startingChapter:16
                                    endingChapter:17],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 3" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNumbers]
                                  startingChapter:18
                                    endingChapter:20],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 4" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNumbers]
                                  startingChapter:21
                                    endingChapter:22],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 5" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNumbers]
                                  startingChapter:23
                                    endingChapter:25],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 6" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNumbers]
                                  startingChapter:26
                                    endingChapter:27],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 7" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNumbers]
                                  startingChapter:28
                                    endingChapter:30],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 8" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNumbers]
                                  startingChapter:31
                                    endingChapter:32],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 9" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNumbers]
                                  startingChapter:33
                                    endingChapter:34],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 10" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNumbers]
                                  startingChapter:35
                                    endingChapter:36],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 11" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexDeuteronomy]
                                  startingChapter:1
                                    endingChapter:2],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 12" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexDeuteronomy]
                                  startingChapter:3
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 13" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexDeuteronomy]
                                  startingChapter:5
                                    endingChapter:7],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 14" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexDeuteronomy]
                                  startingChapter:8
                                    endingChapter:10],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 15" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexDeuteronomy]
                                  startingChapter:11
                                    endingChapter:13],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 16" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexDeuteronomy]
                                  startingChapter:14
                                    endingChapter:16],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 17" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexDeuteronomy]
                                  startingChapter:17
                                    endingChapter:20],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 18" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexDeuteronomy]
                                  startingChapter:21
                                    endingChapter:23],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 19" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexDeuteronomy]
                                  startingChapter:24
                                    endingChapter:27],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 20" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexDeuteronomy]
                                  startingChapter:28
                                    endingChapter:29],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 21" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexDeuteronomy]
                                  startingChapter:30
                                    endingChapter:31],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 22" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexDeuteronomy]
                                  startingChapter:32
                                    endingChapter:34],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                       oneChapter:91],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 23" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJoshua]
                                  startingChapter:1
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 24" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJoshua]
                                  startingChapter:5
                                    endingChapter:8],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 25" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJoshua]
                                  startingChapter:9
                                    endingChapter:11],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 26" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJoshua]
                                  startingChapter:12
                                    endingChapter:15],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 27" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJoshua]
                                  startingChapter:16
                                    endingChapter:18],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 28" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJoshua]
                                  startingChapter:19
                                    endingChapter:21],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 29" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJoshua]
                                  startingChapter:22
                                    endingChapter:24],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 30" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJudges]
                                  startingChapter:1
                                    endingChapter:2],
                ]],
                [[Reading alloc] initWithDay:@"Mar. 31" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJudges]
                                  startingChapter:3
                                    endingChapter:5],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 1" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJudges]
                                  startingChapter:6
                                    endingChapter:7],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 2" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJudges]
                                  startingChapter:8
                                    endingChapter:9],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 3" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJudges]
                                  startingChapter:10
                                    endingChapter:12],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 4" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJudges]
                                  startingChapter:13
                                    endingChapter:15],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 5" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJudges]
                                  startingChapter:16
                                    endingChapter:18],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 6" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJudges]
                                  startingChapter:19
                                    endingChapter:21],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 7" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexRuth]],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 8" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSamuel1]
                                  startingChapter:1
                                    endingChapter:3],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 9" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSamuel1]
                                  startingChapter:4
                                    endingChapter:8],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 10" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSamuel1]
                                  startingChapter:9
                                    endingChapter:12],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 11" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSamuel1]
                                  startingChapter:13
                                    endingChapter:14],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 12" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSamuel1]
                                  startingChapter:15
                                    endingChapter:17],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 13" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSamuel1]
                                  startingChapter:18
                                    endingChapter:20],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                 multipleChapters:@[@11, @59]],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 14" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSamuel1]
                                  startingChapter:21
                                    endingChapter:24],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 15" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                 multipleChapters:@[@7, @27, @31, @34, @52]],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 16" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                 multipleChapters:@[@56, @120, @140, @141, @142]],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 17" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSamuel1]
                                  startingChapter:25
                                    endingChapter:27],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 18" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                 multipleChapters:@[@17, @35, @54, @63]],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 19" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSamuel1]
                                  startingChapter:28
                                    endingChapter:31],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                       oneChapter:18],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 20" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                 multipleChapters:@[@121, @123, @124, @125, @128, @129, @130]],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 21" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSamuel2]
                                  startingChapter:1
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 22" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                 multipleChapters:@[@6, @8, @9, @10, @14, @16, @19, @21]],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 23" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles1]
                                  startingChapter:1
                                    endingChapter:2],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 24" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                 multipleChapters:@[@43, @44, @45, @49, @84, @85, @87]],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 25" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles1]
                                  startingChapter:3
                                    endingChapter:5],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 26" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                 multipleChapters:@[@73, @77, @78]],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 27" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles1]
                                       oneChapter:6],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 28" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                 multipleChapters:@[@81, @88, @92, @93]],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 29" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles1]
                                  startingChapter:7
                                    endingChapter:10],
                ]],
                [[Reading alloc] initWithDay:@"Apr. 30" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:102
                                    endingChapter:104],
                ]],
                [[Reading alloc] initWithDay:@"May 1" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSamuel2]
                                       oneChapter:5],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles1]
                                  startingChapter:11
                                    endingChapter:12],
                ]],
                [[Reading alloc] initWithDay:@"May 2" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                       oneChapter:133],
                ]],
                [[Reading alloc] initWithDay:@"May 3" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:106
                                    endingChapter:107],
                ]],
                [[Reading alloc] initWithDay:@"May 4" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles1]
                                  startingChapter:13
                                    endingChapter:16],
                ]],
                [[Reading alloc] initWithDay:@"May 5" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                 multipleChapters:@[@1, @2, @15, @22, @23, @24, @47, @68]],
                ]],
                [[Reading alloc] initWithDay:@"May 6" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                 multipleChapters:@[@89, @96, @100, @101, @105, @132]],
                ]],
                [[Reading alloc] initWithDay:@"May 7" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSamuel2]
                                  startingChapter:6
                                    endingChapter:7],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles1]
                                       oneChapter:17],
                ]],
                [[Reading alloc] initWithDay:@"May 8" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                 multipleChapters:@[@25, @29, @33, @36, @39]],
                ]],
                [[Reading alloc] initWithDay:@"May 9" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSamuel2]
                                  startingChapter:8
                                    endingChapter:9],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles1]
                                       oneChapter:18],
                ]],
                [[Reading alloc] initWithDay:@"May 10" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                 multipleChapters:@[@50, @53, @60, @75]],
                ]],
                [[Reading alloc] initWithDay:@"May 11" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSamuel2]
                                       oneChapter:10],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles1]
                                       oneChapter:19],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                       oneChapter:20],
                ]],
                [[Reading alloc] initWithDay:@"May 12" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                 multipleChapters:@[@65, @66, @67, @69, @70]],
                ]],
                [[Reading alloc] initWithDay:@"May 13" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSamuel2]
                                  startingChapter:11
                                    endingChapter:12],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles1]
                                       oneChapter:20],
                ]],
                [[Reading alloc] initWithDay:@"May 14" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                 multipleChapters:@[@32, @51, @86, @122]],
                ]],
                [[Reading alloc] initWithDay:@"May 15" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSamuel2]
                                  startingChapter:13
                                    endingChapter:15],
                ]],
                [[Reading alloc] initWithDay:@"May 16" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                 multipleChapters:@[@3, @4, @12, @13, @28, @55]],
                ]],
                [[Reading alloc] initWithDay:@"May 17" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSamuel2]
                                  startingChapter:16
                                    endingChapter:18],
                ]],
                [[Reading alloc] initWithDay:@"May 18" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                 multipleChapters:@[@26, @40, @58, @61, @62, @64]],
                ]],
                [[Reading alloc] initWithDay:@"May 19" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSamuel2]
                                  startingChapter:19
                                    endingChapter:21],
                ]],
                [[Reading alloc] initWithDay:@"May 20" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                 multipleChapters:@[@5, @38, @41, @42]],
                ]],
                [[Reading alloc] initWithDay:@"May 21" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSamuel2]
                                  startingChapter:22
                                    endingChapter:23],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                       oneChapter:57],
                ]],
                [[Reading alloc] initWithDay:@"May 22" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                 multipleChapters:@[@95, @97, @98, @99]],
                ]],
                [[Reading alloc] initWithDay:@"May 23" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSamuel2]
                                       oneChapter:24],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles1]
                                  startingChapter:21
                                    endingChapter:22],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                       oneChapter:30],
                ]],
                [[Reading alloc] initWithDay:@"May 24" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:108
                                    endingChapter:110],
                ]],
                [[Reading alloc] initWithDay:@"May 25" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles1]
                                  startingChapter:23
                                    endingChapter:25],
                ]],
                [[Reading alloc] initWithDay:@"May 26" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                 multipleChapters:@[@131, @138, @139, @143, @144, @145]],
                ]],
                [[Reading alloc] initWithDay:@"May 27" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles1]
                                  startingChapter:26
                                    endingChapter:29],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                       oneChapter:127],
                ]],
                [[Reading alloc] initWithDay:@"May 28" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:111
                                    endingChapter:118],
                ]],
                [[Reading alloc] initWithDay:@"May 29" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings1]
                                  startingChapter:1
                                    endingChapter:2],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                 multipleChapters:@[@37, @71, @94]],
                ]],
                [[Reading alloc] initWithDay:@"May 30" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                       oneChapter:119],
                ]],
                [[Reading alloc] initWithDay:@"May 31" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings1]
                                  startingChapter:3
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 1" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles2]
                                       oneChapter:1],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                       oneChapter:72],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 2" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexSongOfSolomon]],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 3" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                  startingChapter:1
                                    endingChapter:3],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 4" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                  startingChapter:4
                                    endingChapter:6],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 5" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                  startingChapter:7
                                    endingChapter:9],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 6" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                  startingChapter:10
                                    endingChapter:12],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 7" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                  startingChapter:13
                                    endingChapter:15],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 8" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                  startingChapter:16
                                    endingChapter:18],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 9" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                  startingChapter:19
                                    endingChapter:21],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 10" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                  startingChapter:22
                                    endingChapter:24],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 11" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings1]
                                  startingChapter:5
                                    endingChapter:6],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles2]
                                  startingChapter:2
                                    endingChapter:3],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 12" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings1]
                                       oneChapter:7],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles2]
                                       oneChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 13" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings1]
                                       oneChapter:8],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles2]
                                       oneChapter:5],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 14" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles2]
                                  startingChapter:6
                                    endingChapter:7],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                       oneChapter:136],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 15" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                 multipleChapters:@[@134, @146, @147, @148, @149, @150]],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 16" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings1]
                                       oneChapter:9],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles2]
                                       oneChapter:8],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 17" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                  startingChapter:25
                                    endingChapter:26],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 18" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                  startingChapter:27
                                    endingChapter:29],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 19" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEcclesiastes]
                                  startingChapter:1
                                    endingChapter:6],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 20" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEcclesiastes]
                                  startingChapter:7
                                    endingChapter:12],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 21" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings1]
                                  startingChapter:10
                                    endingChapter:11],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles2]
                                       oneChapter:9],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 22" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexProverbs]
                                  startingChapter:30
                                    endingChapter:31],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 23" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings1]
                                  startingChapter:12
                                    endingChapter:13],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 24" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles2]
                                  startingChapter:10
                                    endingChapter:12],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 25" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings1]
                                       oneChapter:15],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles2]
                                  startingChapter:13
                                    endingChapter:16],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 26" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings1]
                                       oneChapter:16],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles2]
                                       oneChapter:17],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 27" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings1]
                                  startingChapter:17
                                    endingChapter:19],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 28" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings1]
                                  startingChapter:20
                                    endingChapter:21],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 29" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings1]
                                       oneChapter:22],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles2]
                                       oneChapter:18],
                ]],
                [[Reading alloc] initWithDay:@"Jun. 30" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles2]
                                  startingChapter:19
                                    endingChapter:23],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 1" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexObadiah]],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                  startingChapter:82
                                    endingChapter:83],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 2" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings2]
                                  startingChapter:1
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 3" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings2]
                                  startingChapter:5
                                    endingChapter:8],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 4" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings2]
                                  startingChapter:9
                                    endingChapter:11],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 5" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings2]
                                  startingChapter:12
                                    endingChapter:13],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles2]
                                       oneChapter:24],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 6" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings2]
                                       oneChapter:14],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles2]
                                       oneChapter:25],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 7" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJonah]],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 8" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings2]
                                       oneChapter:15],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles2]
                                       oneChapter:26],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 9" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexIsaiah]
                                  startingChapter:1
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 10" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexIsaiah]
                                  startingChapter:5
                                    endingChapter:8],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 11" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexAmos]
                                  startingChapter:1
                                    endingChapter:5],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 12" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexAmos]
                                  startingChapter:6
                                    endingChapter:9],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 13" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles2]
                                       oneChapter:27],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexIsaiah]
                                  startingChapter:9
                                    endingChapter:12],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 14" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMicah]],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 15" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles2]
                                       oneChapter:28],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings2]
                                  startingChapter:16
                                    endingChapter:17],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 16" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexIsaiah]
                                  startingChapter:13
                                    endingChapter:17],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 17" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexIsaiah]
                                  startingChapter:18
                                    endingChapter:22],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 18" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexIsaiah]
                                  startingChapter:23
                                    endingChapter:27],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 19" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings2]
                                       oneChapter:18],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles2]
                                  startingChapter:29
                                    endingChapter:31],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                       oneChapter:48],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 20" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexHosea]
                                  startingChapter:1
                                    endingChapter:7],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 21" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexHosea]
                                  startingChapter:8
                                    endingChapter:14],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 22" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexIsaiah]
                                  startingChapter:28
                                    endingChapter:30],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 23" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexIsaiah]
                                  startingChapter:31
                                    endingChapter:34],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 24" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexIsaiah]
                                  startingChapter:35
                                    endingChapter:36],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 25" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexIsaiah]
                                  startingChapter:37
                                    endingChapter:39],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                       oneChapter:76],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 26" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexIsaiah]
                                  startingChapter:40
                                    endingChapter:43],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 27" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexIsaiah]
                                  startingChapter:44
                                    endingChapter:48],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 28" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings2]
                                       oneChapter:19],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                 multipleChapters:@[@46, @80, @135]],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 29" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexIsaiah]
                                  startingChapter:49
                                    endingChapter:53],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 30" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexIsaiah]
                                  startingChapter:54
                                    endingChapter:58],
                ]],
                [[Reading alloc] initWithDay:@"Jul. 31" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexIsaiah]
                                  startingChapter:59
                                    endingChapter:63],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 1" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexIsaiah]
                                  startingChapter:64
                                    endingChapter:66],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 2" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings2]
                                  startingChapter:20
                                    endingChapter:21],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 3" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles2]
                                  startingChapter:32
                                    endingChapter:33],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 4" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNahum]],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 5" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings2]
                                  startingChapter:22
                                    endingChapter:23],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles2]
                                  startingChapter:34
                                    endingChapter:35],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 6" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexZephaniah]],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 7" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJeremiah]
                                  startingChapter:1
                                    endingChapter:3],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 8" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJeremiah]
                                  startingChapter:4
                                    endingChapter:6],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 9" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJeremiah]
                                  startingChapter:7
                                    endingChapter:9],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 10" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJeremiah]
                                  startingChapter:10
                                    endingChapter:13],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 11" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJeremiah]
                                  startingChapter:14
                                    endingChapter:17],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 12" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJeremiah]
                                  startingChapter:18
                                    endingChapter:22],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 13" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJeremiah]
                                  startingChapter:23
                                    endingChapter:24],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 14" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJeremiah]
                                  startingChapter:26
                                    endingChapter:29],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 15" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJeremiah]
                                  startingChapter:30
                                    endingChapter:31],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 16" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJeremiah]
                                  startingChapter:32
                                    endingChapter:34],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 17" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJeremiah]
                                  startingChapter:35
                                    endingChapter:37],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 18" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJeremiah]
                                  startingChapter:38
                                    endingChapter:40],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                 multipleChapters:@[@74, @79]],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 19" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexKings2]
                                  startingChapter:24
                                    endingChapter:25],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexChronicles2]
                                       oneChapter:36],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 20" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexHabakkuk]],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 21" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJeremiah]
                                  startingChapter:41
                                    endingChapter:45],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 22" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJeremiah]
                                  startingChapter:46
                                    endingChapter:48],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 23" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJeremiah]
                                  startingChapter:49
                                    endingChapter:50],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 24" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJeremiah]
                                  startingChapter:51
                                    endingChapter:52],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 25" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLamentations]
                                  startingChapter:1
                                    endingChapter:2],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 26" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLamentations]
                                  startingChapter:3
                                    endingChapter:5],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 27" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEzekiel]
                                  startingChapter:1
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 28" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEzekiel]
                                  startingChapter:5
                                    endingChapter:8],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 29" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEzekiel]
                                  startingChapter:9
                                    endingChapter:12],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 30" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEzekiel]
                                  startingChapter:13
                                    endingChapter:15],
                ]],
                [[Reading alloc] initWithDay:@"Aug. 31" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEzekiel]
                                  startingChapter:16
                                    endingChapter:17],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 1" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEzekiel]
                                  startingChapter:18
                                    endingChapter:20],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 2" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEzekiel]
                                  startingChapter:21
                                    endingChapter:22],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 3" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEzekiel]
                                  startingChapter:23
                                    endingChapter:24],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 4" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEzekiel]
                                  startingChapter:25
                                    endingChapter:27],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 5" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEzekiel]
                                  startingChapter:28
                                    endingChapter:30],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 6" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEzekiel]
                                  startingChapter:31
                                    endingChapter:33],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 7" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEzekiel]
                                  startingChapter:34
                                    endingChapter:36],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 8" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEzekiel]
                                  startingChapter:37
                                    endingChapter:39],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 9" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEzekiel]
                                  startingChapter:40
                                    endingChapter:42],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 10" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEzekiel]
                                  startingChapter:43
                                    endingChapter:45],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 11" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEzekiel]
                                  startingChapter:46
                                    endingChapter:48],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 12" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJoel]],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 13" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexDaniel]
                                  startingChapter:1
                                    endingChapter:3],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 14" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexDaniel]
                                  startingChapter:4
                                    endingChapter:6],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 15" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexDaniel]
                                  startingChapter:7
                                    endingChapter:9],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 16" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexDaniel]
                                  startingChapter:10
                                    endingChapter:12],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 17" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEzra]
                                  startingChapter:1
                                    endingChapter:3],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 18" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEzra]
                                  startingChapter:4
                                    endingChapter:6],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                       oneChapter:137],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 19" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexHaggai]],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 20" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexZechariah]
                                  startingChapter:1
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 21" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexZechariah]
                                  startingChapter:5
                                    endingChapter:9],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 22" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexZechariah]
                                  startingChapter:10
                                    endingChapter:14],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 23" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEsther]
                                  startingChapter:1
                                    endingChapter:5],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 24" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEsther]
                                  startingChapter:6
                                    endingChapter:10],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 25" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEzra]
                                  startingChapter:7
                                    endingChapter:10],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 26" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNehemiah]
                                  startingChapter:1
                                    endingChapter:5],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 27" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNehemiah]
                                  startingChapter:6
                                    endingChapter:7],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 28" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNehemiah]
                                  startingChapter:8
                                    endingChapter:10],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 29" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexNehemiah]
                                  startingChapter:11
                                    endingChapter:13],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPsalms]
                                       oneChapter:126],
                ]],
                [[Reading alloc] initWithDay:@"Sep. 30" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMalachi]],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 1" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLuke]
                                       oneChapter:1],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJohn]
                                       oneChapter:1],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 2" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                       oneChapter:1],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLuke]
                                       oneChapter:2],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 3" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                       oneChapter:2],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 4" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                       oneChapter:3],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMark]
                                       oneChapter:1],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLuke]
                                       oneChapter:3],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 5" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                       oneChapter:4],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLuke]
                                  startingChapter:4
                                    endingChapter:5],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 6" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJohn]
                                  startingChapter:2
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 7" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                       oneChapter:8],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMark]
                                       oneChapter:2],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 8" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJohn]
                                       oneChapter:5],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 9" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                       oneChapter:12],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMark]
                                       oneChapter:3],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLuke]
                                       oneChapter:6],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 10" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                  startingChapter:5
                                    endingChapter:7],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 11" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                       oneChapter:9],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLuke]
                                       oneChapter:7],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 12" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                       oneChapter:11],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 13" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLuke]
                                       oneChapter:11],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 14" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                       oneChapter:13],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLuke]
                                       oneChapter:8],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 15" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMark]
                                  startingChapter:4
                                    endingChapter:5],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 16" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                       oneChapter:10],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 17" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                       oneChapter:14],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMark]
                                       oneChapter:6],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLuke]
                                       oneChapter:9],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 18" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJohn]
                                       oneChapter:6],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 19" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                       oneChapter:15],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMark]
                                       oneChapter:7],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 20" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                       oneChapter:16],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMark]
                                       oneChapter:8],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 21" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                       oneChapter:17],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMark]
                                       oneChapter:9],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 22" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                       oneChapter:18],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 23" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJohn]
                                  startingChapter:7
                                    endingChapter:8],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 24" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJohn]
                                  startingChapter:9
                                    endingChapter:10],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 25" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLuke]
                                       oneChapter:10],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 26" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLuke]
                                  startingChapter:12
                                    endingChapter:13],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 27" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLuke]
                                  startingChapter:14
                                    endingChapter:15],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 28" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLuke]
                                  startingChapter:16
                                    endingChapter:17],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 29" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJohn]
                                       oneChapter:11],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 30" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLuke]
                                       oneChapter:18],
                ]],
                [[Reading alloc] initWithDay:@"Oct. 31" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                       oneChapter:19],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMark]
                                       oneChapter:10],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 1" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                  startingChapter:20
                                    endingChapter:21],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 2" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLuke]
                                       oneChapter:19],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 3" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMark]
                                       oneChapter:11],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJohn]
                                       oneChapter:12],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 4" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                       oneChapter:22],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMark]
                                       oneChapter:12],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 5" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                       oneChapter:23],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLuke]
                                  startingChapter:20
                                    endingChapter:21],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 6" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMark]
                                       oneChapter:13],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 7" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                       oneChapter:24],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 8" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                       oneChapter:25],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 9" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                       oneChapter:26],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMark]
                                       oneChapter:14],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 10" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLuke]
                                       oneChapter:22],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJohn]
                                       oneChapter:13],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 11" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJohn]
                                  startingChapter:14
                                    endingChapter:17],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 12" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                       oneChapter:27],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMark]
                                       oneChapter:15],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 13" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLuke]
                                       oneChapter:23],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJohn]
                                  startingChapter:18
                                    endingChapter:19],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 14" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMatthew]
                                       oneChapter:28],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexMark]
                                       oneChapter:16],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 15" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexLuke]
                                       oneChapter:24],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJohn]
                                  startingChapter:20
                                    endingChapter:21],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 16" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexActs]
                                  startingChapter:1
                                    endingChapter:3],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 17" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexActs]
                                  startingChapter:4
                                    endingChapter:6],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 18" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexActs]
                                  startingChapter:7
                                    endingChapter:8],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 19" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexActs]
                                  startingChapter:9
                                    endingChapter:10],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 20" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexActs]
                                  startingChapter:11
                                    endingChapter:12],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 21" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexActs]
                                  startingChapter:13
                                    endingChapter:14],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 22" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJames]],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 23" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexActs]
                                  startingChapter:15
                                    endingChapter:16],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 24" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGalatians]
                                  startingChapter:1
                                    endingChapter:3],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 25" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexGalatians]
                                  startingChapter:4
                                    endingChapter:6],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 26" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexActs]
                                       oneChapter:17],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 27" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexThessalonians1]],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexThessalonians2]],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 28" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexActs]
                                  startingChapter:18
                                    endingChapter:19],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 29" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexCorinthians1]
                                  startingChapter:1
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Nov. 30" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexCorinthians1]
                                  startingChapter:5
                                    endingChapter:8],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 1" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexCorinthians1]
                                  startingChapter:9
                                    endingChapter:11],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 1" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexCorinthians1]
                                  startingChapter:12
                                    endingChapter:14],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 3" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexCorinthians1]
                                  startingChapter:15
                                    endingChapter:16],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 4" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexCorinthians2]
                                  startingChapter:1
                                    endingChapter:4],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 5" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexCorinthians2]
                                  startingChapter:5
                                    endingChapter:9],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 6" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexCorinthians2]
                                  startingChapter:10
                                    endingChapter:13],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 7" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexRomans]
                                  startingChapter:1
                                    endingChapter:3],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 8" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexRomans]
                                  startingChapter:4
                                    endingChapter:7],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 9" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexRomans]
                                  startingChapter:8
                                    endingChapter:10],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 10" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexRomans]
                                  startingChapter:11
                                    endingChapter:13],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 11" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexRomans]
                                  startingChapter:14
                                    endingChapter:16],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 12" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexActs]
                                  startingChapter:20
                                    endingChapter:23],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 13" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexActs]
                                  startingChapter:24
                                    endingChapter:26],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 14" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexActs]
                                  startingChapter:27
                                    endingChapter:28],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 15" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexColossians]],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPhilemon]],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 16" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexEphesians]],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 17" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPhilippians]],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 18" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexTimothy1]],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 19" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexTitus]],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 20" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPeter1]],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 21" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexHebrews]
                                  startingChapter:1
                                    endingChapter:6],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 22" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexHebrews]
                                  startingChapter:7
                                    endingChapter:10],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 23" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexHebrews]
                                  startingChapter:11
                                    endingChapter:13],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 24" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexTimothy2]],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 25" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexPeter2]],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJude]],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 26" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJohn1]],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 27" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJohn2]],
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexJohn3]],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 28" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexRevelation]
                                  startingChapter:1
                                    endingChapter:5],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 29" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexRevelation]
                                  startingChapter:6
                                    endingChapter:11],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 30" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexRevelation]
                                  startingChapter:12
                                    endingChapter:18],
                ]],
                [[Reading alloc] initWithDay:@"Dec. 31" passages:@[
                    [[Passage alloc] initWithBook:[[Book alloc] initWithIndex:BookIndexRevelation]
                                  startingChapter:19
                                    endingChapter:22],
                ]],
            ];
    };
}

@end
