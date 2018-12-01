//
//  BRTranslation.h
//  bible-reading
//
//  Created by John Bender on 11/29/18.
//  Copyright © 2018 Bender Systems. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BRTranslation : NSObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *version;
@property (nonatomic, copy) NSString *language;
@property (nonatomic, copy) NSString *key;

-(id) initWithDictionary:(NSDictionary*)dict;

-(NSDictionary*) dictionaryRepresentation;

@end

NS_ASSUME_NONNULL_END
