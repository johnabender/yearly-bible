//
//  BRTableCell.m
//  bible-reading
//
//  Created by John Bender on 1/10/14.
//  Copyright (c) 2014 Bender Systems. All rights reserved.
//

#import "BRTableCell.h"
#import "BRReadingManager.h"

@implementation BRTableCell

static NSDateFormatter *inputFormatter = nil;
static NSDateFormatter *mayFormatter = nil;
static NSDateFormatter *outputFormatter = nil;
static NSDateFormatter *yearFormatter = nil;
static NSDateFormatter *firstFormatter = nil;

static const CGFloat dragOvershoot = 60.;

+(void) initialize
{
    inputFormatter = [NSDateFormatter new];
    inputFormatter.dateFormat = @"MMM. d yyyy";

    mayFormatter = [NSDateFormatter new];
    mayFormatter.dateFormat = @"MMM d yyyy";

    outputFormatter = [NSDateFormatter new];
    outputFormatter.dateFormat = @"EEE, MMM. d";

    yearFormatter = [NSDateFormatter new];
    yearFormatter.dateFormat = @"yyyy";

    firstFormatter = [NSDateFormatter new];
    firstFormatter.dateFormat = @"HH:mm:ss yyyy MM dd";
}

-(NSDate*) dateFromString:(NSString*)string inYear:(NSString*)yearString
{
    NSString *combinedString = [NSString stringWithFormat:@"%@ %@", string, yearString];

    if( [string hasPrefix:@"May"] )
        return [mayFormatter dateFromString:combinedString];
    else
        return [inputFormatter dateFromString:combinedString];
}


-(NSDate*) dateFromString:(NSString*)string yearOffset:(NSInteger)yearOffset firstDate:(NSDate*)firstDate
{
    NSDate *now = [NSDate date];
    NSString *yearString = [yearFormatter stringFromDate:now];

    NSDate *readingDate = [self dateFromString:string inYear:yearString];
    if( yearOffset == 0 ) return readingDate;

    NSInteger year = [[yearFormatter stringFromDate:readingDate] integerValue];
    NSInteger yearInit = year;
    if( (yearOffset > 0 && [readingDate timeIntervalSinceDate:now] < 0) ) {
        year += yearOffset;
    }
    else if( (yearOffset < 0 && [readingDate timeIntervalSinceDate:firstDate] < 0) ) {
        year -= yearOffset;
    }
    if( year == yearInit ) return readingDate; // save computation if no change

    return [self dateFromString:string inYear:[NSString stringWithFormat:@"%d", year]];
}

-(void) populateWithReading:(BRReading*)reading_ firstDay:(NSString*)firstDay
{
    reading = reading_;
    readingLabel.text = reading.passage;

    NSDate *firstDate = [self dateFromString:firstDay yearOffset:0 firstDate:nil];
    NSInteger yearOffset = 0;
    if( [firstDate timeIntervalSinceNow] > 0 ) {
        // first reading's date in current year is later than now,
        // so it must refer to last year
        yearOffset = 1;
    }
    else {
        // first reading's date in current year is earlier than now,
        // so when we reach Jan. 1, that's next year (unless Jan. 1 is first)
        if( ![firstDay isEqualToString:@"Jan. 1"] )
            yearOffset = -1;
    }

    NSDate *readingDate = [self dateFromString:reading.day yearOffset:yearOffset firstDate:firstDate];

    dateLabel.text = [outputFormatter stringFromDate:readingDate];

    [self markReadOrUnread];
    [self performSelector:@selector(markReadOrUnread) withObject:nil afterDelay:0.];
}

-(void) markReadOrUnread
{
    if( reading.read )
        [self markRead];
    else
        [self markUnread];
}

-(void) markUnread
{
    labelContainer.center = CGPointMake( self.frame.size.width/2.,
                                         self.contentView.center.y );
    labelContainer.alpha = 1.;
}

-(void) markRead
{
    labelContainer.center = CGPointMake( self.frame.size.width/2. - dragOvershoot,
                                         self.contentView.center.y );
    labelContainer.alpha = 0.25;
}


-(void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    if( movingTouch ) return;
    movingTouch = [touches anyObject];

    CGPoint location = [movingTouch locationInView:labelContainer.superview];
    touchOffset = CGPointMake( labelContainer.center.x - location.x,
                               labelContainer.center.y - location.y );
}

-(void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    if( !movingTouch ) return;
    if( ![touches containsObject:movingTouch] ) return;

    CGPoint location = [movingTouch locationInView:labelContainer.superview];
    if( reading.read ) {
        labelContainer.center = CGPointMake( MAX( location.x + touchOffset.x,
                                                  -dragOvershoot ),
                                            labelContainer.center.y );
    }
    else {
        labelContainer.center = CGPointMake( MIN( location.x + touchOffset.x,
                                                  self.frame.size.width/2. ),
                                             labelContainer.center.y );
    }
}

-(void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    movingTouch = nil;

    if( reading.read ) {
        // mark unread?
        if( labelContainer.frame.origin.x < 0. ) {
            [UIView animateWithDuration:0.2 animations:^{
                [self markRead];
            }];
        }
        else {
            [BRReadingManager readingWasUnread:reading];
            [UIView animateWithDuration:0.2 animations:^{
                [self markUnread];
            }];
        }
    }
    else {
        // mark read?
        if( labelContainer.frame.origin.x < -dragOvershoot ) {
            [BRReadingManager readingWasRead:reading];
            [UIView animateWithDuration:0.2 animations:^{
                [self markRead];
            }];
        }
        else {
            [UIView animateWithDuration:0.2 animations:^{
                [self markUnread];
            }];
        }
    }
}

-(void) touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    /* if touch was cancelled, don't change state
    movingTouch = nil;

    [UIView animateWithDuration:0.2 animations:^{
        [self markReadOrUnread];
    }];
     */

    // probably touch cancelled because of scrolling or edge of screen,
    // so pretend it's the same thing as a purposeful touch end
    [self touchesEnded:touches withEvent:nil];
}

@end
