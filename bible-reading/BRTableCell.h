//
//  BRTableCell.h
//  bible-reading
//
//  Created by John Bender on 1/10/14.
//  Copyright (c) 2014 Bender Systems. All rights reserved.
//

#import <UIKit/UIKit.h>

@class Reading;

@interface BRTableCell : UITableViewCell
{
    Reading *reading;

    CGPoint touchStart;
    UITouch *movingTouch;

    __weak IBOutlet UIView *labelContainer;
    __weak IBOutlet UILabel *dateLabel;
    __weak IBOutlet UILabel *readingLabel;

    __weak IBOutlet NSLayoutConstraint *containerLeadingConstraint;
    __weak IBOutlet NSLayoutConstraint *containerTrailingConstraint;
}

@property (nonatomic, strong) void (^selectionHandler)(Reading*, UIImpactFeedbackGenerator*);

-(void) populateWithReading:(Reading*)reading firstDay:(NSString*)firstDay;

@end
