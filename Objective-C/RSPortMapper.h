//
//  RSPortMapper.h
//  RevS
//
//  Created by lzbdd on 13-9-15.
//  Copyright (c) 2013年 lzbdd. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PortMapper;

@protocol RSPortMapperDelegate <NSObject>

@optional

- (void)mapper:(PortMapper *)mapper didMapWithSuccess:(BOOL)success;

@end

@interface RSPortMapper : NSObject

+ (void)start;
+ (void)stop;
+ (NSString *)publicAddress;
+ (NSString *)privateAddress;
+ (void)addDelegate:(id)delegate;
+ (void)addMapperWithPort:(UInt16)port;

@end