//
//  BRTableCell.h
//  bible-reading
//
//  Created by John Bender on 1/10/14.
//  Copyright (c) 2014 Bender Systems. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BRReading.h"

@interface BRTableCell : UITableViewCell
{
    BRReading *reading;

    CGPoint touchStart;
    UITouch *movingTouch;

    __weak IBOutlet UIView *labelContainer;
    __weak IBOutlet UILabel *dateLabel;
    __weak IBOutlet UILabel *readingLabel;

    __weak IBOutlet NSLayoutConstraint *containerLeadingConstraint;
    __weak IBOutlet NSLayoutConstraint *containerTrailingConstraint;
}

-(void) populateWithReading:(BRReading*)reading firstDay:(NSString*)firstDay;

@end
