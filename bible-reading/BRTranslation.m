//
//  BRTranslation.m
//  bible-reading
//
//  Created by John Bender on 11/29/18.
//  Copyright © 2018 Bender Systems. All rights reserved.
//

#import "BRTranslation.h"

@implementation BRTranslation

-(id) initWithDictionary:(NSDictionary*)dict
{
    self = [super init];
    if( self ) {
        self.name = dict[@"name"];
        self.key = dict[@"key"];
    }
    return self;
}

-(NSDictionary*) dictionaryRepresentation
{
    NSMutableDictionary *dict = [NSMutableDictionary new];
    dict[@"name"] = self.name;
    dict[@"key"] = self.key;
    return [NSDictionary dictionaryWithDictionary:dict];
}

-(NSString*) description
{
    return [NSString stringWithFormat:@"%@ (%@)", self.name, self.key];
}

@end
