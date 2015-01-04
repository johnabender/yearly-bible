//
//  BRAppDelegate.m
//  bible-reading
//
//  Created by John Bender on 1/5/14.
//  Copyright (c) 2014 Bender Systems. All rights reserved.
//

#import "BRAppDelegate.h"
#import "BRReadingManager.h"
#import "bible_reading-Swift.h"

@implementation BRAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
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


-(void) application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings
{
    // If navigation is still on the settings VC and the user allowed notifications,
    // then trigger the notifications scheduling UI.

    if( [self.window.rootViewController isKindOfClass:[UINavigationController class]] ) {
        UINavigationController *navVC = (UINavigationController*)self.window.rootViewController;
        if( [navVC.topViewController class] == [BRSettingsViewController class] ) {
            BRSettingsViewController *settingsVC = (BRSettingsViewController*)navVC.topViewController;
            if( (notificationSettings.types & settingsVC.desiredFlags) != 0 ) {
                [settingsVC pressedReminderButton];
            }
        }
    }
}

-(void)        application:(UIApplication *)application
handleActionWithIdentifier:(NSString *)identifier
      forLocalNotification:(UILocalNotification *)notification
         completionHandler:(void (^)())completionHandler
{
    // Currently, we only send one kind of local notification, from BRSettingsViewController.
    // It's a daily reading reminder, and its only action is "mark as read" for that reading.

    BRReading *readingToMark = [[BRReading alloc] initWithDictionary:notification.userInfo];

    for( BRReading *reading in [BRReadingManager readings] ) {
        if( [reading isEqual:readingToMark] ) {
            [BRReadingManager readingWasRead:reading];
            break;
        }
    }

    completionHandler();
}

@end
