//
//  BRReading.h
//  bible-reading
//
//  Created by John Bender on 1/12/14.
//  Copyright (c) 2014 Bender Systems. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BRReading : NSObject

@property (nonatomic, copy) NSString *day;
@property (nonatomic, copy) NSString *passage;
@property (nonatomic, assign) BOOL read;

-(id) initWithDictionary:(NSDictionary*)dict;

-(NSDictionary*) dictionaryRepresentation;

@end
