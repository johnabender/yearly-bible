//
//  BRViewController.m
//  bible-reading
//
//  Created by John Bender on 1/5/14.
//  Copyright (c) 2014 Bender Systems. All rights reserved.
//

#import "BRViewController.h"
#import "BRAppDelegate.h"
#import "BRReadingManager.h"
#import "BRTableCell.h"
#import "bible_reading-Swift.h"

enum {
    alertNone,
    alertResetting,
    alertShifting
};


@interface BRViewController () <UIAlertViewDelegate, UITableViewDataSource, UITableViewDelegate>
{
    NSArray *readings;

    NSInteger alertState;
}

@property (nonatomic, weak) IBOutlet UITableView *tableView;

-(IBAction) resetReadings;

@end


@implementation BRViewController

-(void) viewDidLoad
{
    [super viewDidLoad];

    UIBarButtonItem *toggleItem = [[UIBarButtonItem alloc] initWithTitle:@"  Shift  "
                                                                   style:UIBarButtonItemStylePlain
                                                                  target:self
                                                                  action:@selector(tapHandler)];
    self.navigationItem.leftBarButtonItems = @[self.navigationItem.leftBarButtonItem, toggleItem];

    ((BRAppDelegate*)[[UIApplication sharedApplication] delegate]).navController = self.navigationController;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appWillEnterForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];

    [self performSelector:@selector(scrollToFirstUnread) withObject:nil afterDelay:0.5];
}

-(void) didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];

    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


-(void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [self initializeViewForAppearance];
}

-(void) appWillEnterForeground:(NSNotification*)note
{
    [self initializeViewForAppearance];
}

-(void) initializeViewForAppearance
{
    readings = [BRReadingManager readings];
    assert( [readings count] == 365 );

    NSDateFormatter *yearFormatter = [NSDateFormatter new];
    yearFormatter.dateFormat = @"yyyy";
    NSString *year = [yearFormatter stringFromDate:[NSDate date]];
    self.navigationItem.title = year;

    [_tableView reloadData];
}


-(void) changeFont
{
    UIFont *navFont = [UIFont fontWithName:@"Freebooter Script" size:20.];
    [[UIBarButtonItem appearance] setTitleTextAttributes:@{NSFontAttributeName: navFont}
                                                forState:UIControlStateNormal];
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
                                message:@"Unmarks all readings and removes calendar shift."
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
    NSUInteger dayOfYear = [[NSCalendar calendarWithIdentifier:NSCalendarIdentifierISO8601]
                            ordinalityOfUnit:NSCalendarUnitDay
                            inUnit:NSCalendarUnitYear
                            forDate:[NSDate date]];
    NSString *suffix = @"th";
    if( dayOfYear % 10 == 1 ) suffix = @"st";
    else if( dayOfYear % 10 == 2 ) suffix = @"nd";
    else if( dayOfYear % 10 == 3 ) suffix = @"rd";
    NSString *message = [NSString stringWithFormat:@"You can shift the calendar to start reading any day of the year. For example, today is the %d%@ day of the year, so to start reading today, you could shift the calendar by %d days.\n\nEnter number of days to shift.",
                         (int)dayOfYear, suffix, (int)dayOfYear - 1];

    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Shift Calendar"
                                                    message:message
                                                   delegate:self
                                          cancelButtonTitle:@"Cancel"
                                          otherButtonTitles:@"Shift", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;

    UITextField *textField = [alert textFieldAtIndex:0];
    textField.keyboardType = UIKeyboardTypeNumberPad;
    textField.text = [NSString stringWithFormat:@"%d", (int)dayOfYear - 1];

    [alert show];
    alertState = alertShifting;
}


#pragma mark - Alert view delegate

-(void) alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if( buttonIndex != alertView.cancelButtonIndex ) {
        switch( alertState ) {
            case alertResetting: {
                readings = [BRReadingManager resetReadings];
                [NSOperationQueue.mainQueue addOperationWithBlock:^{
                    [self.tableView reloadData];
                }];
                break;
            }
            case alertShifting: {
                NSInteger shift = [[alertView textFieldAtIndex:0].text integerValue];
                if( shift > 0 && shift < [readings count] ) {
                    readings = [BRReadingManager shiftReadings:shift];
                    [NSOperationQueue.mainQueue addOperationWithBlock:^{
                        [self.tableView reloadData];
                    }];
                }
                break;
            }
        }
    }

    alertState = alertNone;
}

@end
