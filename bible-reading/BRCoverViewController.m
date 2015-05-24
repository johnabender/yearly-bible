//
//  BRCoverViewController.m
//  bible-reading
//
//  Created by John Bender on 5/24/15.
//  Copyright (c) 2015 Bender Systems. All rights reserved.
//

#import "BRCoverViewController.h"
#import <QuartzCore/QuartzCore.h>

@interface BRCoverViewController()
{
    __weak IBOutlet UIImageView *coverView;
    __weak IBOutlet NSLayoutConstraint *leftConstraint;
    __weak IBOutlet NSLayoutConstraint *rightConstraint;
}
@end


@implementation BRCoverViewController

-(void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    if( coverView ) {
        coverView.layer.anchorPoint = CGPointMake( 0., 0.5 );
        leftConstraint.constant = -coverView.frame.size.width/2.;
        rightConstraint.constant = -leftConstraint.constant;
        [self.view layoutIfNeeded];

        coverView.layer.transform = CATransform3DMakeRotation( -M_PI/2., 0., 1., 0. );
        CABasicAnimation *a = [CABasicAnimation animationWithKeyPath:@"transform"];
        a.fromValue = [NSValue valueWithCATransform3D:CATransform3DIdentity];
        a.toValue = [NSValue valueWithCATransform3D:coverView.layer.transform];
        a.duration = 0.3;
        a.delegate = self;
        [coverView.layer addAnimation:a forKey:@"openCover"];
    }
}

-(void) animationDidStop:(CAAnimation *)anim finished:(BOOL)flag
{
    [coverView removeFromSuperview];
}

@end
