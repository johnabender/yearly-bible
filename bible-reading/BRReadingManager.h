//
//  BRReadingManager.h
//  bible-reading
//
//  Created by John Bender on 1/5/14.
//  Copyright (c) 2014 Bender Systems. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BRReading.h"

@interface BRReadingManager : NSObject

+(NSArray*) readings;

+(NSArray*) resetReadings;

+(NSArray*) shiftReadings:(NSInteger)offset;

+(void) readingWasRead:(BRReading*)reading;
+(void) readingWasUnread:(BRReading*)reading;

+(NSString*) firstDay;

@end
