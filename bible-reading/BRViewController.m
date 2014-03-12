//
//  BRViewController.m
//  bible-reading
//
//  Created by John Bender on 1/5/14.
//  Copyright (c) 2014 Bender Systems. All rights reserved.
//

#import "BRViewController.h"
#import "BRReadingManager.h"
#import "BRTableCell.h"

@interface BRViewController ()
{
    NSArray *readings;
}

-(IBAction) resetReadings;

@end


@implementation BRViewController

-(void) viewDidLoad
{
    [super viewDidLoad];

    readings = [BRReadingManager readings];
    assert( [readings count] == 365 );

    NSDateFormatter *yearFormatter = [NSDateFormatter new];
    yearFormatter.dateFormat = @"yyyy";
    NSString *year = [yearFormatter stringFromDate:[NSDate date]];
    self.navigationItem.title = year;

    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Readings"
                                                                             style:UIBarButtonItemStylePlain
                                                                            target:self.navigationController
                                                                            action:@selector(popViewControllerAnimated:)];
}

-(void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    [self scrollToFirstUnread];
}


-(void) scrollToFirstUnread
{
    for( NSInteger i = 0; i < [readings count]; i++ ) {
        BRReading *reading = readings[i];
        if( !reading.read ) {
            [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0]
                                  atScrollPosition:UITableViewScrollPositionMiddle
                                          animated:YES];
            break;
        }
    }
}


-(NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

-(NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [readings count];
}

-(UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    BRTableCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];

    BRReading *day = readings[indexPath.row];
    [cell populateWithReading:day];

    return cell;
}


-(IBAction) resetReadings
{
    readings = [BRReadingManager resetReadings];
    [self.tableView reloadData];
}

@end
