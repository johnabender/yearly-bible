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

static const CGFloat dragOvershoot = 60.;

-(void) checkFormatters
{
    if( inputFormatter == nil ) {
        inputFormatter = [NSDateFormatter new];
        inputFormatter.dateFormat = @"MMM. d yyyy";
    }
    if( mayFormatter == nil ) {
        mayFormatter = [NSDateFormatter new];
        mayFormatter.dateFormat = @"MMM d yyyy";
    }
    if( outputFormatter == nil ) {
        outputFormatter = [NSDateFormatter new];
        outputFormatter.dateFormat = @"EEE, MMM. d";
    }
    if( yearFormatter == nil ) {
        yearFormatter = [NSDateFormatter new];
        yearFormatter.dateFormat = @"yyyy";
    }
}

-(NSDate*) dateFromString:(NSString*)string
{
    NSDate *now = [NSDate date];
    NSString *year = [yearFormatter stringFromDate:now];
    NSString *combinedString = [NSString stringWithFormat:@"%@ %@", string, year];

    if( [string hasPrefix:@"May"] )
        return [mayFormatter dateFromString:combinedString];
    else
        return [inputFormatter dateFromString:combinedString];
}

-(void) populateWithReading:(BRReading*)reading_
{
    reading = reading_;
    readingLabel.text = reading.passage;

    [self checkFormatters];
    NSDate *date = [self dateFromString:reading.day];
    dateLabel.text = [outputFormatter stringFromDate:date];

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
    movingTouch = nil;

    [UIView animateWithDuration:0.2 animations:^{
        [self markReadOrUnread];
    }];
}

@end
