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
#import "bible_reading-Swift.h"

enum {
    alertNone,
    alertResetting,
    alertShifting
};


@interface BRViewController () <UIAlertViewDelegate>
{
    NSArray *readings;

    NSInteger alertState;
}

-(IBAction) resetReadings;

@end


@implementation BRViewController

-(void) viewDidLoad
{
    [super viewDidLoad];

    readings = [BRReadingManager readings];
    assert( [readings count] == 365 );

    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Readings"
                                                                             style:UIBarButtonItemStylePlain
                                                                            target:self.navigationController
                                                                            action:@selector(popViewControllerAnimated:)];

    UIBarButtonItem *toggleItem = [[UIBarButtonItem alloc] initWithTitle:@"  ^ "
                                                                   style:UIBarButtonItemStylePlain
                                                                  target:self
                                                                  action:@selector(tapHandler)];
    toggleItem.tintColor = [UIColor colorWithRed:1. green:0. blue:0. alpha:0.7];
    self.navigationItem.leftBarButtonItems = @[self.navigationItem.leftBarButtonItem, toggleItem];
}

-(void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    [self.tableView reloadData];

    NSDateFormatter *yearFormatter = [NSDateFormatter new];
    yearFormatter.dateFormat = @"yyyy";
    NSString *year = [yearFormatter stringFromDate:[NSDate date]];
    self.navigationItem.title = year;

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


#pragma mark - Table view data source

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
    [cell populateWithReading:day firstDay:[BRReadingManager firstDay]];

    return cell;
}


#pragma mark - Action handlers

-(IBAction) resetReadings
{
    [[[UIAlertView alloc] initWithTitle:@"Reset Readings?"
                                message:nil
                               delegate:self
                      cancelButtonTitle:@"Cancel"
                      otherButtonTitles:@"Reset", nil]
     show];
    alertState = alertResetting;
}


-(void) pushSettingsVC
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    BRSettingsViewController *settingsVC = [storyboard instantiateViewControllerWithIdentifier:@"BRSettingsViewController"];
    [self.navigationController pushViewController:settingsVC animated:YES];
}


-(void) tapHandler
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Days to Shift"
                                                    message:@"Enter number of days to shift."
                                                   delegate:self
                                          cancelButtonTitle:@"Cancel"
                                          otherButtonTitles:@"Shift", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;

    UITextField *textField = [alert textFieldAtIndex:0];
    textField.keyboardType = UIKeyboardTypeNumberPad;

    [alert show];
    alertState = alertShifting;
}


#pragma mark - Alert view delegate

-(void) alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if( buttonIndex != alertView.cancelButtonIndex ) {
        switch( alertState ) {
            case alertResetting:
                readings = [BRReadingManager resetReadings];
                [self.tableView reloadData];
                break;
            case alertShifting: {
                NSInteger shift = [[alertView textFieldAtIndex:0].text integerValue];
                if( shift > 0 && shift < [readings count] ) {
                    readings = [BRReadingManager shiftReadings:shift];
                    [self.tableView reloadData];
                }
            }
        }
    }

    alertState = alertNone;
}

@end
