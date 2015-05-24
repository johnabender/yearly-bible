//
//  BRMarginLabel.m
//  bible-reading
//
//  Created by John Bender on 5/14/15.
//  Copyright (c) 2015 Bender Systems. All rights reserved.
//

#import "BRMarginLabel.h"

@implementation BRMarginLabel

// http://stackoverflow.com/questions/20985085
static const CGFloat GUTTER = 2.0; // make this large enough to accommodate the largest font in your app

- (void)drawRect:(CGRect)rect
{
    // fixes word wrapping issue
    CGRect newRect = rect;
    newRect.origin.x = rect.origin.x + GUTTER;
    newRect.size.width = rect.size.width - 2 * GUTTER;
    [self.attributedText drawInRect:newRect];
}

- (UIEdgeInsets)alignmentRectInsets
{
    return UIEdgeInsetsMake(0, GUTTER, 0, GUTTER);
}

- (CGSize)intrinsicContentSize
{
    CGSize size = [super intrinsicContentSize];
    size.width += 2 * GUTTER;
    return size;
}

@end
