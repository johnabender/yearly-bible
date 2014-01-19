//
//  BRReading.m
//  bible-reading
//
//  Created by John Bender on 1/12/14.
//  Copyright (c) 2014 Bender Systems. All rights reserved.
//

#import "BRReading.h"

@implementation BRReading

-(id) initWithDictionary:(NSDictionary*)dict
{
    self = [super init];
    if( self ) {
        self.day = dict[@"day"];
        self.passage = dict[@"passage"];
        if( dict[@"read"] )
            self.read = TRUE;
    }
    return self;
}

-(NSDictionary*) dictionaryRepresentation
{
    NSMutableDictionary *dict = [NSMutableDictionary new];
    dict[@"day"] = self.day;
    dict[@"passage"] = self.passage;
    if( self.read )
        dict[@"read"] = @TRUE;
    return [NSDictionary dictionaryWithDictionary:dict];
}

@end
