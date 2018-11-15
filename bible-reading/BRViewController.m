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


@interface BRViewController () <UITableViewDataSource, UITableViewDelegate>
{
    NSArray *readings;
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
                                                                  action:@selector(shiftReadings)];
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

    [cell setSelectionHandler:^(BRReading *reading) {
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
        BRReadingViewController *readingVC = (BRReadingViewController*)[storyboard instantiateViewControllerWithIdentifier:@"BRReadingViewController"];
        if( readingVC ) {
            readingVC.reading = reading;
            [self presentViewController:readingVC animated:YES completion:nil];
            readingVC.markReadAction = ^(BRReading *reading) {
                [BRReadingManager readingWasRead:reading];
                [self.tableView reloadData];
            };
        }
    }];

    if( [day.day isEqualToString:@"Jan. 1"] ) cell.selectionHandler( day ); ///////////////////////////////////////////////

    return cell;
}


#pragma mark - Action handlers

-(IBAction) resetReadings
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Reset Readings?"
                                                                   message:@"Unmarks all readings and removes calendar shift."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Reset"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action)
    {
        self->readings = [BRReadingManager resetReadings];
        [NSOperationQueue.mainQueue addOperationWithBlock:^{
            [self dismissViewControllerAnimated:YES completion:nil];
            [self.tableView reloadData];
        }];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:^(UIAlertAction * _Nonnull action)
    {
        [self dismissViewControllerAnimated:YES completion:nil];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}


-(void) pushSettingsVC
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    BRSettingsViewController *settingsVC = [storyboard instantiateViewControllerWithIdentifier:@"BRSettingsViewController"];
    [self.navigationController pushViewController:settingsVC animated:YES];
}


-(void) shiftReadings
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

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Shift Calendar"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Shift"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action)
    {
        NSInteger shift = [alert.textFields[0].text integerValue];
        if( shift > 0 && shift < [self->readings count] ) {
            self->readings = [BRReadingManager shiftReadings:shift];
            [NSOperationQueue.mainQueue addOperationWithBlock:^{
                [self dismissViewControllerAnimated:YES completion:nil];
                [self.tableView reloadData];
            }];
        }
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:^(UIAlertAction * _Nonnull action)
    {
        [self dismissViewControllerAnimated:YES completion:nil];
    }]];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.text = [NSString stringWithFormat:@"%d", (int)dayOfYear - 1];
    }];
    [self presentViewController:alert animated:YES completion:nil];
}


@end
