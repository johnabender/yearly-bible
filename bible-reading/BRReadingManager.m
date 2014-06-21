//
//  BRReadingManager.m
//  bible-reading
//
//  Created by John Bender on 1/5/14.
//  Copyright (c) 2014 Bender Systems. All rights reserved.
//

#import "BRReadingManager.h"

@implementation BRReadingManager

static NSArray *readings = nil;
static NSString *firstDay = nil;

+(NSArray*) readings
{
    if( !readings ) {
        NSArray *r = [NSArray arrayWithContentsOfURL:[self fileURL]];
        if( r ) {
            NSArray *diskReadings = [self readingArrayFromDictionaryArray:r];
            [self fixReadings:diskReadings];
        }
        else
            [self resetReadings];

        [self updateFirstDay];
    }

    return readings;
}

+(NSArray*) readingArrayFromDictionaryArray:(NSArray*)dicts
{
    NSMutableArray *_readings = [NSMutableArray arrayWithCapacity:[dicts count]];
    for( NSDictionary *dict in dicts ) {
        BRReading *reading = [[BRReading alloc] initWithDictionary:dict];
        [_readings addObject:reading];
    }
    return [NSArray arrayWithArray:_readings];
}


+(NSArray*) dictionaryArrayFromReadingArray:(NSArray*)_readings
{
    NSMutableArray *dicts = [NSMutableArray arrayWithCapacity:[_readings count]];
    for( BRReading *reading in _readings )
        [dicts addObject:[reading dictionaryRepresentation]];
    return [NSArray arrayWithArray:dicts];
}


+(void) readingWasRead:(BRReading*)reading
{
    reading.read = TRUE;
    [self save];
}

+(void) readingWasUnread:(BRReading*)reading
{
    reading.read = FALSE;
    [self save];
}


+(NSArray*) resetReadings
{
    NSArray *r = [self newReadings];
    readings = [self readingArrayFromDictionaryArray:r];
    [self save];
    return readings;
}


+(NSArray*) shiftReadings:(NSInteger)offset
{
    assert( offset < [readings count] );
    
    NSMutableArray *newReadings = [NSMutableArray arrayWithCapacity:[readings count]];
    NSArray *unshiftedReadings = [self readingArrayFromDictionaryArray:[self newReadings]];

    NSInteger i = offset, j = 0;
    for( ; i < [readings count]; i++, j++ ) {
        BRReading *ur = unshiftedReadings[j];
        BRReading *sr = readings[i];
        BRReading *pr = readings[j];
        ur.day = sr.day;
        ur.read = pr.read;
        [newReadings addObject:ur];
    }
    for( ; [newReadings count] < [readings count]; i++, j++ ) {
        BRReading *ur = unshiftedReadings[j];
        BRReading *sr = readings[i - [readings count]];
        BRReading *pr = readings[j];
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

    NSArray *newReadings = [self newReadings];
    newReadings = [self readingArrayFromDictionaryArray:newReadings];
    assert( [existingReadings count] == [newReadings count] );

    NSMutableArray *fixedReadings = [NSMutableArray arrayWithCapacity:[existingReadings count]];
    /*
    NSInteger offset = 0;
    BRReading *nr = newReadings[offset];
    BRReading *er = existingReadings[0];
    while( ![nr.day isEqualToString:er.day] ) {
        offset++;
        nr = newReadings[offset];
    }
     */

    for( NSInteger i = 0; i < [existingReadings count]; i++ ) {
        /*
        if( offset + i < [newReadings count] )
            nr = newReadings[offset + i];
        else
            nr = newReadings[offset + i - [newReadings count]];
         */
        BRReading *nr = newReadings[i];
        BRReading *er = existingReadings[i];
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


+(NSURL*) fileURL
{
    NSURL *documentsPath = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    return [documentsPath URLByAppendingPathComponent:@"My Readings.plist"];
}


+(void) save
{
    NSArray *dicts = [self dictionaryArrayFromReadingArray:readings];
    [dicts writeToURL:[self fileURL] atomically:YES];

    [self updateFirstDay];
}


+(void) updateFirstDay
{
    BRReading *first = readings[0];
    firstDay = first.day;
}


+(NSString*) firstDay
{
    return firstDay;
}


+(NSArray*) newReadings
{
    return @[
             @{@"day": @"Jan. 1", @"passage": @"Gen. 1-2"},
             @{@"day": @"Jan. 2", @"passage": @"Josh. 1-6"},
             @{@"day": @"Jan. 3", @"passage": @"Ps. 1-4"},
             @{@"day": @"Jan. 4", @"passage": @"Job 1-2"},
             @{@"day": @"Jan. 5", @"passage": @"Isa. 1-5"},
             @{@"day": @"Jan. 6", @"passage": @"Mat. 1-3"},
             @{@"day": @"Jan. 7", @"passage": @"Rom. 1-2"},
             @{@"day": @"Jan. 8", @"passage": @"Gen. 3-4"},
             @{@"day": @"Jan. 9", @"passage": @"Josh. 7-11"},
             @{@"day": @"Jan. 10", @"passage": @"Ps. 5-7"},
             @{@"day": @"Jan. 11", @"passage": @"Job 3-5"},
             @{@"day": @"Jan. 12", @"passage": @"Isa. 6-10"},
             @{@"day": @"Jan. 13", @"passage": @"Mat. 4-5"},
             @{@"day": @"Jan. 14", @"passage": @"Rom. 3-4"},
             @{@"day": @"Jan. 15", @"passage": @"Gen. 5-8"},
             @{@"day": @"Jan. 16", @"passage": @"Josh. 12-17"},
             @{@"day": @"Jan. 17", @"passage": @"Ps. 8-11"},
             @{@"day": @"Jan. 18", @"passage": @"Job 6-7"},
             @{@"day": @"Jan. 19", @"passage": @"Isa. 11-15"},
             @{@"day": @"Jan. 20", @"passage": @"Mat. 6-7"},
             @{@"day": @"Jan. 21", @"passage": @"Rom. 5-7"},
             @{@"day": @"Jan. 22", @"passage": @"Gen. 9-11"},
             @{@"day": @"Jan. 23", @"passage": @"Josh. 18-21"},
             @{@"day": @"Jan. 24", @"passage": @"Ps. 12-17"},
             @{@"day": @"Jan. 25", @"passage": @"Job 8-10"},
             @{@"day": @"Jan. 26", @"passage": @"Isa. 16-22"},
             @{@"day": @"Jan. 27", @"passage": @"Mat. 8-10"},
             @{@"day": @"Jan. 28", @"passage": @"Rom. 8-9"},
             @{@"day": @"Jan. 29", @"passage": @"Gen. 12-14"},
             @{@"day": @"Jan. 30", @"passage": @"Josh. 22-24"},
             @{@"day": @"Jan. 31", @"passage": @"Ps. 18"},
             @{@"day": @"Feb. 1", @"passage": @"Job 11-14"},
             @{@"day": @"Feb. 2", @"passage": @"Isa. 23-26"},
             @{@"day": @"Feb. 3", @"passage": @"Mat. 11-13"},
             @{@"day": @"Feb. 4", @"passage": @"Rom. 10-11"},
             @{@"day": @"Feb. 5", @"passage": @"Gen. 15-17"},
             @{@"day": @"Feb. 6", @"passage": @"Judg. 1-5"},
             @{@"day": @"Feb. 7", @"passage": @"Ps. 19-21"},
             @{@"day": @"Feb. 8", @"passage": @"Job 15-17"},
             @{@"day": @"Feb. 9", @"passage": @"Isa. 27-30"},
             @{@"day": @"Feb. 10", @"passage": @"Mat. 14-16"},
             @{@"day": @"Feb. 11", @"passage": @"Rom. 12-13"},
             @{@"day": @"Feb. 12", @"passage": @"Gen. 18-20"},
             @{@"day": @"Feb. 13", @"passage": @"Judg. 6-9"},
             @{@"day": @"Feb. 14", @"passage": @"Ps. 22-24"},
             @{@"day": @"Feb. 15", @"passage": @"Job 18-19"},
             @{@"day": @"Feb. 16", @"passage": @"Isa. 31-35"},
             @{@"day": @"Feb. 17", @"passage": @"Mat. 17-18"},
             @{@"day": @"Feb. 18", @"passage": @"Rom. 14-16"},
             @{@"day": @"Feb. 19", @"passage": @"Gen. 21-23"},
             @{@"day": @"Feb. 20", @"passage": @"Judg. 10-16"},
             @{@"day": @"Feb. 21", @"passage": @"Ps. 25-26"},
             @{@"day": @"Feb. 22", @"passage": @"Job 20-22"},
             @{@"day": @"Feb. 23", @"passage": @"Isa. 36-40"},
             @{@"day": @"Feb. 24", @"passage": @"Mat. 19-20"},
             @{@"day": @"Feb. 25", @"passage": @"1 Cor. 1-3"},
             @{@"day": @"Feb. 26", @"passage": @"Gen. 24-25"},
             @{@"day": @"Feb. 27", @"passage": @"Judg. 17-21"},
             @{@"day": @"Feb. 28", @"passage": @"Ps. 27-28"},
             @{@"day": @"Mar. 1", @"passage": @"Job 23-24"},
             @{@"day": @"Mar. 2", @"passage": @"Isa. 41-44"},
             @{@"day": @"Mar. 3", @"passage": @"Mat. 21-23"},
             @{@"day": @"Mar. 4", @"passage": @"1 Cor. 4-6"},
             @{@"day": @"Mar. 5", @"passage": @"Gen. 26-28"},
             @{@"day": @"Mar. 6", @"passage": @"Ruth"},
             @{@"day": @"Mar. 7", @"passage": @"Ps. 29-30"},
             @{@"day": @"Mar. 8", @"passage": @"Job 25-28"},
             @{@"day": @"Mar. 9", @"passage": @"Isa. 45-48"},
             @{@"day": @"Mar. 10", @"passage": @"Mat. 24-25"},
             @{@"day": @"Mar. 11", @"passage": @"1 Cor. 7-9"},
             @{@"day": @"Mar. 12", @"passage": @"Gen. 29-30"},
             @{@"day": @"Mar. 13", @"passage": @"1 Sam. 1-4"},
             @{@"day": @"Mar. 14", @"passage": @"Ps. 31-33"},
             @{@"day": @"Mar. 15", @"passage": @"Job 29-31"},
             @{@"day": @"Mar. 16", @"passage": @"Isa. 49-52"},
             @{@"day": @"Mar. 17", @"passage": @"Mat. 26"},
             @{@"day": @"Mar. 18", @"passage": @"1 Cor. 10-11"},
             @{@"day": @"Mar. 19", @"passage": @"Gen. 31-33"},
             @{@"day": @"Mar. 20", @"passage": @"1 Sam. 5-12"},
             @{@"day": @"Mar. 21", @"passage": @"Ps. 34-35"},
             @{@"day": @"Mar. 22", @"passage": @"Job 32-34"},
             @{@"day": @"Mar. 23", @"passage": @"Isa. 53-57"},
             @{@"day": @"Mar. 24", @"passage": @"Mat. 27-28"},
             @{@"day": @"Mar. 25", @"passage": @"1 Cor. 12-14"},
             @{@"day": @"Mar. 26", @"passage": @"Gen. 34-36"},
             @{@"day": @"Mar. 27", @"passage": @"1 Sam. 13-15"},
             @{@"day": @"Mar. 28", @"passage": @"Ps. 36-37"},
             @{@"day": @"Mar. 29", @"passage": @"Job 35-36"},
             @{@"day": @"Mar. 30", @"passage": @"Isa. 58-62"},
             @{@"day": @"Mar. 31", @"passage": @"Mark 1-3"},
             @{@"day": @"Apr. 1", @"passage": @"1 Cor. 15-16"},
             @{@"day": @"Apr. 2", @"passage": @"Gen. 37-39"},
             @{@"day": @"Apr. 3", @"passage": @"1 Sam. 16-20"},
             @{@"day": @"Apr. 4", @"passage": @"Ps. 38-39"},
             @{@"day": @"Apr. 5", @"passage": @"Job 37"},
             @{@"day": @"Apr. 6", @"passage": @"Isa. 63-66"},
             @{@"day": @"Apr. 7", @"passage": @"Mark 4-5"},
             @{@"day": @"Apr. 8", @"passage": @"2 Cor. 1-3"},
             @{@"day": @"Apr. 9", @"passage": @"Gen. 40-42"},
             @{@"day": @"Apr. 10", @"passage": @"1 Sam. 21-25"},
             @{@"day": @"Apr. 11", @"passage": @"Ps. 40-41"},
             @{@"day": @"Apr. 12", @"passage": @"Job 38"},
             @{@"day": @"Apr. 13", @"passage": @"Jer. 1-4"},
             @{@"day": @"Apr. 14", @"passage": @"Mark 6-7"},
             @{@"day": @"Apr. 15", @"passage": @"2 Cor. 4-7"},
             @{@"day": @"Apr. 16", @"passage": @"Gen. 43-45"},
             @{@"day": @"Apr. 17", @"passage": @"1 Sam. 26-31"},
             @{@"day": @"Apr. 18", @"passage": @"Ps. 42-44"},
             @{@"day": @"Apr. 19", @"passage": @"Job 39"},
             @{@"day": @"Apr. 20", @"passage": @"Jer. 5-9"},
             @{@"day": @"Apr. 21", @"passage": @"Mark 8-9"},
             @{@"day": @"Apr. 22", @"passage": @"2 Cor. 8-10"},
             @{@"day": @"Apr. 23", @"passage": @"Gen. 46-47"},
             @{@"day": @"Apr. 24", @"passage": @"2 Sam. 1-5"},
             @{@"day": @"Apr. 25", @"passage": @"Ps. 45-48"},
             @{@"day": @"Apr. 26", @"passage": @"Job 40-42"},
             @{@"day": @"Apr. 27", @"passage": @"Jer. 10-13"},
             @{@"day": @"Apr. 28", @"passage": @"Mark 10-11"},
             @{@"day": @"Apr. 29", @"passage": @"2 Cor. 11-13"},
             @{@"day": @"Apr. 30", @"passage": @"Gen. 48-50"},
             @{@"day": @"May 1", @"passage": @"2 Sam. 6-10"},
             @{@"day": @"May 2", @"passage": @"Ps. 49-50"},
             @{@"day": @"May 3", @"passage": @"Prov. 1-2"},
             @{@"day": @"May 4", @"passage": @"Jer. 14-17"},
             @{@"day": @"May 5", @"passage": @"Mark 12-13"},
             @{@"day": @"May 6", @"passage": @"Gal. 1-3"},
             @{@"day": @"May 7", @"passage": @"Exod. 1-2"},
             @{@"day": @"May 8", @"passage": @"2 Sam. 11-14"},
             @{@"day": @"May 9", @"passage": @"Ps. 51-54"},
             @{@"day": @"May 10", @"passage": @"Prov. 3-4"},
             @{@"day": @"May 11", @"passage": @"Jer. 18-22"},
             @{@"day": @"May 12", @"passage": @"Mark 14-16"},
             @{@"day": @"May 13", @"passage": @"Gal. 4-6"},
             @{@"day": @"May 14", @"passage": @"Exod. 3-4"},
             @{@"day": @"May 15", @"passage": @"2 Sam. 15-19"},
             @{@"day": @"May 16", @"passage": @"Ps. 55-57"},
             @{@"day": @"May 17", @"passage": @"Prov. 5-7"},
             @{@"day": @"May 18", @"passage": @"Jer. 23-27"},
             @{@"day": @"May 19", @"passage": @"Luke 1-2"},
             @{@"day": @"May 20", @"passage": @"Eph. 1-3"},
             @{@"day": @"May 21", @"passage": @"Exod. 5-7"},
             @{@"day": @"May 22", @"passage": @"2 Sam. 20-24"},
             @{@"day": @"May 23", @"passage": @"Ps. 58-60"},
             @{@"day": @"May 24", @"passage": @"Prov. 8-9"},
             @{@"day": @"May 25", @"passage": @"Jer. 28-31"},
             @{@"day": @"May 26", @"passage": @"Luke 3-4"},
             @{@"day": @"May 27", @"passage": @"Eph. 4-6"},
             @{@"day": @"May 28", @"passage": @"Exod. 8-10"},
             @{@"day": @"May 29", @"passage": @"1 Kin. 1-4"},
             @{@"day": @"May 30", @"passage": @"Ps. 61-64"},
             @{@"day": @"May 31", @"passage": @"Prov. 10"},
             @{@"day": @"Jun. 1", @"passage": @"Jer. 32-36"},
             @{@"day": @"Jun. 2", @"passage": @"Luke 5-6"},
             @{@"day": @"Jun. 3", @"passage": @"Phil. 1-2"},
             @{@"day": @"Jun. 4", @"passage": @"Exod. 11-13"},
             @{@"day": @"Jun. 5", @"passage": @"1 Kin. 5-7"},
             @{@"day": @"Jun. 6", @"passage": @"Ps. 65-67"},
             @{@"day": @"Jun. 7", @"passage": @"Prov. 11"},
             @{@"day": @"Jun. 8", @"passage": @"Jer. 37-43"},
             @{@"day": @"Jun. 9", @"passage": @"Luke 7-8"},
             @{@"day": @"Jun. 10", @"passage": @"Phil. 3-4"},
             @{@"day": @"Jun. 11", @"passage": @"Exod. 14-16"},
             @{@"day": @"Jun. 12", @"passage": @"1 Kin. 8-11"},
             @{@"day": @"Jun. 13", @"passage": @"Ps. 68-69"},
             @{@"day": @"Jun. 14", @"passage": @"Prov. 12"},
             @{@"day": @"Jun. 15", @"passage": @"Jer. 44-48"},
             @{@"day": @"Jun. 16", @"passage": @"Luke 9-10"},
             @{@"day": @"Jun. 17", @"passage": @"Col. 1-2"},
             @{@"day": @"Jun. 18", @"passage": @"Exod. 17-20"},
             @{@"day": @"Jun. 19", @"passage": @"1 Kin. 12-16"},
             @{@"day": @"Jun. 20", @"passage": @"Ps. 70-72"},
             @{@"day": @"Jun. 21", @"passage": @"Prov. 13"},
             @{@"day": @"Jun. 22", @"passage": @"Jer. 49-50"},
             @{@"day": @"Jun. 23", @"passage": @"Luke 11-12"},
             @{@"day": @"Jun. 24", @"passage": @"Col. 3-4"},
             @{@"day": @"Jun. 25", @"passage": @"Exod. 21-24"},
             @{@"day": @"Jun. 26", @"passage": @"1 Kin. 17-20"},
             @{@"day": @"Jun. 27", @"passage": @"Ps. 73-74"},
             @{@"day": @"Jun. 28", @"passage": @"Prov. 14"},
             @{@"day": @"Jun. 29", @"passage": @"Jer. 51-52"},
             @{@"day": @"Jun. 30", @"passage": @"Luke 13-14"},
             @{@"day": @"Jul. 1", @"passage": @"1 Th. 1-3"},
             @{@"day": @"Jul. 2", @"passage": @"Exod. 25-30"},
             @{@"day": @"Jul. 3", @"passage": @"1 Kin. 21-22"},
             @{@"day": @"Jul. 4", @"passage": @"Ps. 75-77"},
             @{@"day": @"Jul. 5", @"passage": @"Prov. 15"},
             @{@"day": @"Jul. 6", @"passage": @"Lamentations"},
             @{@"day": @"Jul. 7", @"passage": @"Luke 15-16"},
             @{@"day": @"Jul. 8", @"passage": @"1 Th. 4-5"},
             @{@"day": @"Jul. 9", @"passage": @"Exod. 31-34"},
             @{@"day": @"Jul. 10", @"passage": @"2 Kin. 1-4"},
             @{@"day": @"Jul. 11", @"passage": @"Ps. 78"},
             @{@"day": @"Jul. 12", @"passage": @"Prov. 16"},
             @{@"day": @"Jul. 13", @"passage": @"Eze. 1-6"},
             @{@"day": @"Jul. 14", @"passage": @"Luke 17-18"},
             @{@"day": @"Jul. 15", @"passage": @"2 Thess."},
             @{@"day": @"Jul. 16", @"passage": @"Exod. 35-40"},
             @{@"day": @"Jul. 17", @"passage": @"2 Kin. 5-8"},
             @{@"day": @"Jul. 18", @"passage": @"Ps. 79-81"},
             @{@"day": @"Jul. 19", @"passage": @"Prov. 17"},
             @{@"day": @"Jul. 20", @"passage": @"Eze. 7-12"},
             @{@"day": @"Jul. 21", @"passage": @"Luke 19-20"},
             @{@"day": @"Jul. 22", @"passage": @"1 Tim. 1-3"},
             @{@"day": @"Jul. 23", @"passage": @"Lev. 1-8"},
             @{@"day": @"Jul. 24", @"passage": @"2 Kin. 9-12"},
             @{@"day": @"Jul. 25", @"passage": @"Ps. 82-85"},
             @{@"day": @"Jul. 26", @"passage": @"Prov. 18"},
             @{@"day": @"Jul. 27", @"passage": @"Eze. 13-17"},
             @{@"day": @"Jul. 28", @"passage": @"Luke 21-22"},
             @{@"day": @"Jul. 29", @"passage": @"1 Tim. 4-6"},
             @{@"day": @"Jul. 30", @"passage": @"Lev. 9-15"},
             @{@"day": @"Jul. 31", @"passage": @"2 Kin. 13-16"},
             @{@"day": @"Aug. 1", @"passage": @"Ps. 86-88"},
             @{@"day": @"Aug. 2", @"passage": @"Prov. 19"},
             @{@"day": @"Aug. 3", @"passage": @"Eze. 18-21"},
             @{@"day": @"Aug. 4", @"passage": @"Luke 23-24"},
             @{@"day": @"Aug. 5", @"passage": @"2 Timothy"},
             @{@"day": @"Aug. 6", @"passage": @"Lev. 16-22"},
             @{@"day": @"Aug. 7", @"passage": @"2 Kin. 17-20"},
             @{@"day": @"Aug. 8", @"passage": @"Ps. 89"},
             @{@"day": @"Aug. 9", @"passage": @"Prov. 20"},
             @{@"day": @"Aug. 10", @"passage": @"Eze. 22-25"},
             @{@"day": @"Aug. 11", @"passage": @"John 1-2"},
             @{@"day": @"Aug. 12", @"passage": @"Titus"},
             @{@"day": @"Aug. 13", @"passage": @"Lev. 23-27"},
             @{@"day": @"Aug. 14", @"passage": @"2 Kin. 21-25"},
             @{@"day": @"Aug. 15", @"passage": @"Ps. 90-93"},
             @{@"day": @"Aug. 16", @"passage": @"Prov. 21"},
             @{@"day": @"Aug. 17", @"passage": @"Eze. 26-30"},
             @{@"day": @"Aug. 18", @"passage": @"John 3-4"},
             @{@"day": @"Aug. 19", @"passage": @"Philemon"},
             @{@"day": @"Aug. 20", @"passage": @"Num. 1-4"},
             @{@"day": @"Aug. 21", @"passage": @"1 Chr. 1-4"},
             @{@"day": @"Aug. 22", @"passage": @"Ps. 94-96"},
             @{@"day": @"Aug. 23", @"passage": @"Prov. 22"},
             @{@"day": @"Aug. 24", @"passage": @"Eze. 31-34"},
             @{@"day": @"Aug. 25", @"passage": @"John 5-6"},
             @{@"day": @"Aug. 26", @"passage": @"Heb. 1-3"},
             @{@"day": @"Aug. 27", @"passage": @"Num. 5-9"},
             @{@"day": @"Aug. 28", @"passage": @"1 Chr. 5-9"},
             @{@"day": @"Aug. 29", @"passage": @"Ps. 97-101"},
             @{@"day": @"Aug. 30", @"passage": @"Prov. 23"},
             @{@"day": @"Aug. 31", @"passage": @"Eze. 35-39"},
             @{@"day": @"Sep. 1", @"passage": @"John 7-8"},
             @{@"day": @"Sep. 2", @"passage": @"Heb. 4-7"},
             @{@"day": @"Sep. 3", @"passage": @"Num. 10-12"},
             @{@"day": @"Sep. 4", @"passage": @"1 Chr. 10-13"},
             @{@"day": @"Sep. 5", @"passage": @"Ps. 102-103"},
             @{@"day": @"Sep. 6", @"passage": @"Prov. 24"},
             @{@"day": @"Sep. 7", @"passage": @"Eze. 40-43"},
             @{@"day": @"Sep. 8", @"passage": @"John 9-10"},
             @{@"day": @"Sep. 9", @"passage": @"Heb. 8-9"},
             @{@"day": @"Sep. 10", @"passage": @"Num. 13-14"},
             @{@"day": @"Sep. 11", @"passage": @"1 Chr. 14-17"},
             @{@"day": @"Sep. 12", @"passage": @"Ps. 104-105"},
             @{@"day": @"Sep. 13", @"passage": @"Prov. 25"},
             @{@"day": @"Sep. 14", @"passage": @"Eze. 44-48"},
             @{@"day": @"Sep. 15", @"passage": @"John 11-12"},
             @{@"day": @"Sep. 16", @"passage": @"Heb. 10-11"},
             @{@"day": @"Sep. 17", @"passage": @"Num. 15-17"},
             @{@"day": @"Sep. 18", @"passage": @"1 Chr. 18-22"},
             @{@"day": @"Sep. 19", @"passage": @"Ps. 106"},
             @{@"day": @"Sep. 20", @"passage": @"Prov. 26"},
             @{@"day": @"Sep. 21", @"passage": @"Dan. 1-4"},
             @{@"day": @"Sep. 22", @"passage": @"John 13-14"},
             @{@"day": @"Sep. 23", @"passage": @"Heb. 12-13"},
             @{@"day": @"Sep. 24", @"passage": @"Num. 18-20"},
             @{@"day": @"Sep. 25", @"passage": @"1 Chr. 23-26"},
             @{@"day": @"Sep. 26", @"passage": @"Ps. 107-108"},
             @{@"day": @"Sep. 27", @"passage": @"Prov. 27"},
             @{@"day": @"Sep. 28", @"passage": @"Dan. 5-8"},
             @{@"day": @"Sep. 29", @"passage": @"John 15-16"},
             @{@"day": @"Sep. 30", @"passage": @"James 1-2"},
             @{@"day": @"Oct. 1", @"passage": @"Num. 21-24"},
             @{@"day": @"Oct. 2", @"passage": @"1 Chr. 27-29"},
             @{@"day": @"Oct. 3", @"passage": @"Ps. 109-113"},
             @{@"day": @"Oct. 4", @"passage": @"Prov. 28"},
             @{@"day": @"Oct. 5", @"passage": @"Dan. 9-12"},
             @{@"day": @"Oct. 6", @"passage": @"John 17-19"},
             @{@"day": @"Oct. 7", @"passage": @"James 3-5"},
             @{@"day": @"Oct. 8", @"passage": @"Num. 25-27"},
             @{@"day": @"Oct. 9", @"passage": @"2 Chr. 1-7"},
             @{@"day": @"Oct. 10", @"passage": @"Ps. 114-118"},
             @{@"day": @"Oct. 11", @"passage": @"Prov. 29"},
             @{@"day": @"Oct. 12", @"passage": @"Hos. 1-7"},
             @{@"day": @"Oct. 13", @"passage": @"John 20-21"},
             @{@"day": @"Oct. 14", @"passage": @"1 Pet. 1-2"},
             @{@"day": @"Oct. 15", @"passage": @"Num. 28-31"},
             @{@"day": @"Oct. 16", @"passage": @"2 Chr. 8-12"},
             @{@"day": @"Oct. 17", @"passage": @"Ps. 119:1-96"},
             @{@"day": @"Oct. 18", @"passage": @"Prov. 30"},
             @{@"day": @"Oct. 19", @"passage": @"Hos. 8-14"},
             @{@"day": @"Oct. 20", @"passage": @"Acts 1-2"},
             @{@"day": @"Oct. 21", @"passage": @"1 Pet. 3-5"},
             @{@"day": @"Oct. 22", @"passage": @"Num. 32-36"},
             @{@"day": @"Oct. 23", @"passage": @"2 Chr. 13-20"},
             @{@"day": @"Oct. 24", @"passage": @"Ps. 119:97-176"},
             @{@"day": @"Oct. 25", @"passage": @"Prov. 31"},
             @{@"day": @"Oct. 26", @"passage": @"Joel"},
             @{@"day": @"Oct. 27", @"passage": @"Acts 3-4"},
             @{@"day": @"Oct. 28", @"passage": @"2 Peter"},
             @{@"day": @"Oct. 29", @"passage": @"Deut. 1-3"},
             @{@"day": @"Oct. 30", @"passage": @"2 Chr. 21-26"},
             @{@"day": @"Oct. 31", @"passage": @"Ps. 120-124"},
             @{@"day": @"Nov. 1", @"passage": @"Ecc. 1-2"},
             @{@"day": @"Nov. 2", @"passage": @"Amos 1-5"},
             @{@"day": @"Nov. 3", @"passage": @"Acts 5-7"},
             @{@"day": @"Nov. 4", @"passage": @"1 Jn. 1-3"},
             @{@"day": @"Nov. 5", @"passage": @"Deut. 4-5"},
             @{@"day": @"Nov. 6", @"passage": @"2 Chr. 27-32"},
             @{@"day": @"Nov. 7", @"passage": @"Ps. 125-129"},
             @{@"day": @"Nov. 8", @"passage": @"Ecc. 3-4"},
             @{@"day": @"Nov. 9", @"passage": @"Amos 6-9"},
             @{@"day": @"Nov. 10", @"passage": @"Acts 8-9"},
             @{@"day": @"Nov. 11", @"passage": @"1 Jn. 4-5"},
             @{@"day": @"Nov. 12", @"passage": @"Deut. 6-9"},
             @{@"day": @"Nov. 13", @"passage": @"2 Chr. 33-36"},
             @{@"day": @"Nov. 14", @"passage": @"Ps. 130-132"},
             @{@"day": @"Nov. 15", @"passage": @"Ecc. 5-6"},
             @{@"day": @"Nov. 16", @"passage": @"Obad., Jon."},
             @{@"day": @"Nov. 17", @"passage": @"Acts 10-12"},
             @{@"day": @"Nov. 18", @"passage": @"2 Jn., 3 Jn."},
             @{@"day": @"Nov. 19", @"passage": @"Deut. 10-13"},
             @{@"day": @"Nov. 20", @"passage": @"Ezra 1-6"},
             @{@"day": @"Nov. 21", @"passage": @"Ps. 133-135"},
             @{@"day": @"Nov. 22", @"passage": @"Ecc. 7-8"},
             @{@"day": @"Nov. 23", @"passage": @"Micah"},
             @{@"day": @"Nov. 24", @"passage": @"Acts 13-14"},
             @{@"day": @"Nov. 25", @"passage": @"Jude"},
             @{@"day": @"Nov. 26", @"passage": @"Deut. 14-17"},
             @{@"day": @"Nov. 27", @"passage": @"Ezra 7-10"},
             @{@"day": @"Nov. 28", @"passage": @"Ps. 136-138"},
             @{@"day": @"Nov. 29", @"passage": @"Ecc. 9-10"},
             @{@"day": @"Nov. 30", @"passage": @"Nah., Hab."},
             @{@"day": @"Dec. 1", @"passage": @"Acts 15-17"},
             @{@"day": @"Dec. 2", @"passage": @"Rev. 1-4"},
             @{@"day": @"Dec. 3", @"passage": @"Deut. 18-22"},
             @{@"day": @"Dec. 4", @"passage": @"Neh. 1-5"},
             @{@"day": @"Dec. 5", @"passage": @"Ps. 139-141"},
             @{@"day": @"Dec. 6", @"passage": @"Ecc. 11-12"},
             @{@"day": @"Dec. 7", @"passage": @"Zeph., Hagg."},
             @{@"day": @"Dec. 8", @"passage": @"Acts 18-20"},
             @{@"day": @"Dec. 9", @"passage": @"Rev. 5-9"},
             @{@"day": @"Dec. 10", @"passage": @"Deut. 23-27"},
             @{@"day": @"Dec. 11", @"passage": @"Neh. 6-10"},
             @{@"day": @"Dec. 12", @"passage": @"Ps. 142-144"},
             @{@"day": @"Dec. 13", @"passage": @"Song 1-2"},
             @{@"day": @"Dec. 14", @"passage": @"Zech. 1-8"},
             @{@"day": @"Dec. 15", @"passage": @"Acts 21-23"},
             @{@"day": @"Dec. 16", @"passage": @"Rev. 10-14"},
             @{@"day": @"Dec. 17", @"passage": @"Deut. 28-29"},
             @{@"day": @"Dec. 18", @"passage": @"Neh. 11-13"},
             @{@"day": @"Dec. 19", @"passage": @"Ps. 145-147"},
             @{@"day": @"Dec. 20", @"passage": @"Song 3-5"},
             @{@"day": @"Dec. 21", @"passage": @"Zech. 9-14"},
             @{@"day": @"Dec. 22", @"passage": @"Acts 24-26"},
             @{@"day": @"Dec. 23", @"passage": @"Rev. 15-19"},
             @{@"day": @"Dec. 24", @"passage": @"Deut. 30-31"},
             @{@"day": @"Dec. 25", @"passage": @"Esther"},
             @{@"day": @"Dec. 26", @"passage": @"Ps. 148-150"},
             @{@"day": @"Dec. 27", @"passage": @"Song 6-8"},
             @{@"day": @"Dec. 28", @"passage": @"Malachi"},
             @{@"day": @"Dec. 29", @"passage": @"Acts 27-28"},
             @{@"day": @"Dec. 30", @"passage": @"Rev. 20-22"},
             @{@"day": @"Dec. 31", @"passage": @"Deut. 32-33"},
             ];
}

@end
