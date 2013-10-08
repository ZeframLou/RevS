//
//  RSPortMapper.h
//  RevS
//
//  Created by lzbdd on 13-9-15.
//  Copyright (c) 2013年 Zebang Liu. All rights reserved.
//  Contact: the.great.lzbdd@gmail.com
/*
 This file is part of RevS.
 
 RevS is free software: you can redistribute it and/or modify
 it under the terms of the GNU Lesser General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 RevS is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU Lesser General Public License for more details.
 
 You should have received a copy of the GNU Lesser General Public License
 along with RevS.  If not, see <http://www.gnu.org/licenses/>.
 */

#import <Foundation/Foundation.h>

@class PortMapper;

@protocol RSPortMapperDelegate <NSObject>

@optional

- (void)mapper:(PortMapper *)mapper didMapWithSuccess:(BOOL)success;
- (void)mapperDidClose:(PortMapper *)mapper;

@end

@interface RSPortMapper : NSObject

+ (void)start;
+ (void)stop;
+ (NSString *)publicAddress;
+ (NSString *)privateAddress;
+ (void)addDelegate:(id)delegate;
+ (void)addMapperWithPort:(UInt16)port;

@end