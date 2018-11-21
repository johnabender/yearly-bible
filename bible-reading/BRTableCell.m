//
//  BRTableCell.m
//  bible-reading
//
//  Created by John Bender on 1/10/14.
//  Copyright (c) 2014 Bender Systems. All rights reserved.
//

#import "BRTableCell.h"
#import "BRReadingManager.h"
#import "bible_reading-Swift.h"

@implementation BRTableCell

static NSDateFormatter *inputFormatter = nil;
static NSDateFormatter *mayFormatter = nil;
static NSDateFormatter *outputFormatter = nil;
static NSDateFormatter *mayOutputFormatter = nil;
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
    outputFormatter.dateFormat = @"EEE., MMM. d";

    mayOutputFormatter = [NSDateFormatter new];
    mayOutputFormatter.dateFormat = @"EEE., MMM d";

    yearFormatter = [NSDateFormatter new];
    yearFormatter.dateFormat = @"yyyy";

    firstFormatter = [NSDateFormatter new];
    firstFormatter.dateFormat = @"HH:mm:ss yyyy MM dd";
}


-(void) awakeFromNib
{
    [super awakeFromNib];

    // TODO: switch to 3D touch
    UILongPressGestureRecognizer *longPressGestureRecognizer = [UILongPressGestureRecognizer new];
    [longPressGestureRecognizer addTarget:self action:@selector(longPress:)];
    [self addGestureRecognizer:longPressGestureRecognizer];
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

    return [self dateFromString:string inYear:[NSString stringWithFormat:@"%d", (int)year]];
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

    if( [reading.day hasPrefix:@"May"] )
        dateLabel.text = [mayOutputFormatter stringFromDate:readingDate];
    else
        dateLabel.text = [outputFormatter stringFromDate:readingDate];

    [self markReadOrUnread];
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
    containerLeadingConstraint.constant = 0.;
    containerTrailingConstraint.constant = 0.;
    labelContainer.alpha = 1.;
}

-(void) markRead
{
    containerLeadingConstraint.constant = -dragOvershoot;
    containerTrailingConstraint.constant = dragOvershoot;
    labelContainer.alpha = 0.25;
}


-(void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    if( movingTouch ) return;
    movingTouch = [touches anyObject];
    touchStart = [movingTouch locationInView:labelContainer.superview];
}

-(void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    if( !movingTouch ) return;
    if( ![touches containsObject:movingTouch] ) return;

    CGPoint location = [movingTouch locationInView:labelContainer.superview];
    CGFloat distanceMoved = location.x - touchStart.x;
    CGFloat newOffset;
    if( reading.read )
        newOffset = -dragOvershoot + distanceMoved;
    else
        newOffset = distanceMoved;
    if( newOffset > 0. ) // rubber band right
        newOffset /= 2.;
    if( newOffset < -dragOvershoot ) // rubber band left
        newOffset = -dragOvershoot - (-dragOvershoot - newOffset)/2.;
    containerLeadingConstraint.constant = newOffset;
    containerTrailingConstraint.constant = -newOffset;
}

-(void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if( !movingTouch ) return;
    if( ![touches containsObject:movingTouch] ) return;
    movingTouch = nil;

    if( reading.read ) {
        // mark unread?
        if( containerLeadingConstraint.constant < 0. ) {
            [UIView animateWithDuration:0.2 animations:^{
                [self markRead];
                [self.contentView layoutIfNeeded];
            }];
        }
        else {
            [BRReadingManager readingWasUnread:reading];
            [UIView animateWithDuration:0.2 animations:^{
                [self markUnread];
                [self.contentView layoutIfNeeded];
            }];
        }
    }
    else {
        // mark read?
        if( containerLeadingConstraint.constant <= -dragOvershoot ) {
            [BRReadingManager readingWasRead:reading];
            [UIView animateWithDuration:0.2 animations:^{
                [self markRead];
                [self.contentView layoutIfNeeded];
            }];
        }
        else {
            [UIView animateWithDuration:0.2 animations:^{
                [self markUnread];
                [self.contentView layoutIfNeeded];
            }];
        }
    }
}

-(void) touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    if( !movingTouch ) return;
    if( ![touches containsObject:movingTouch] ) return;

    /*
    if( -[touchStartTime timeIntervalSinceNow] < 0.1 ) {
        // if touch was cancelled very quickly, don't change state
        movingTouch = nil;
        [self markReadOrUnread];
    }
    else */{
        // probably touch cancelled because of scrolling or edge of screen,
        // so pretend it's the same thing as a purposeful touch end
        [self touchesEnded:touches withEvent:nil];
    }
}

-(void) longPress:(UILongPressGestureRecognizer*)gr
{
    if( gr.state != UIGestureRecognizerStateBegan ) return;

    if( _selectionHandler )
        // TODO: add haptic feedback
        _selectionHandler( reading );
}

-(NSString*) description
{
    return [NSString stringWithFormat:@"%@ %@", dateLabel.text, readingLabel.text];
}

@end
