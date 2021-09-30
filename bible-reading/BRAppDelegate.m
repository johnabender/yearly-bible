//
//  BRAppDelegate.m
//  bible-reading
//
//  Created by John Bender on 1/5/14.
//  Copyright (c) 2014 Bender Systems. All rights reserved.
//

#import <UserNotifications/UserNotifications.h>

#import "BRAppDelegate.h"
#import "BRReadingManager.h"
#import "bible_reading-Swift.h"

@implementation BRAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.

//    for( NSString *name in [UIFont familyNames] ) DLog( @"%@", name );
    UIFont *navFont = [UIFont fontWithName:@"Gentium Basic" size:17.];
    UIColor *buttonColor = [UIColor colorWithRed:235./255. green:65./255. blue:7./255. alpha:1.];

    UINavigationBarAppearance *navBarAppearance = [UINavigationBarAppearance new];
    [navBarAppearance setTitleTextAttributes:@{NSFontAttributeName: navFont}];

    UIBarButtonItemAppearance *buttonAppearance = [UIBarButtonItemAppearance new];
    [buttonAppearance.normal setTitleTextAttributes:@{NSFontAttributeName: navFont}];
    [buttonAppearance.highlighted setTitleTextAttributes:@{NSFontAttributeName: navFont}];
    [buttonAppearance.focused setTitleTextAttributes:@{NSFontAttributeName: navFont}];
    [buttonAppearance.disabled setTitleTextAttributes:@{NSFontAttributeName: navFont}];
    navBarAppearance.buttonAppearance = buttonAppearance;

    [UINavigationBar appearance].standardAppearance = navBarAppearance;
    [UINavigationBar appearance].scrollEdgeAppearance = navBarAppearance;

    [[UIView appearanceWhenContainedInInstancesOfClasses:@[[UIAlertController class]]] setTintColor:buttonColor];

    [[BRReadingManager sharedReadingManager] registerForNotifications];

    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    [BRReadingManager updateScheduledNotifications];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
