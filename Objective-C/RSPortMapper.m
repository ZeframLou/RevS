//
//  RSPortMapper.m
//  RevS
//
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

#import "RevS.h"
#import "PortMapper.h"

static NSMutableArray *mappers;
static NSMutableArray *delegates;
static BOOL started;

@interface RSPortMapper ()

@end

@implementation RSPortMapper

+ (RSPortMapper *)sharedInstance
{
    static RSPortMapper *mapper;
    if (!mapper) {
        mapper = [[RSPortMapper alloc]init];
    }
    return mapper;
}

+ (void)start
{
    [[NSNotificationCenter defaultCenter] addObserver: [RSPortMapper sharedInstance]
                                             selector: @selector(portMappingChanged:)
                                                 name: PortMapperChangedNotification
                                               object: nil];
    for (PortMapper *mapper in mappers) {
        dispatch_async(dispatch_queue_create("waitMappingResult", NULL), ^{
            [mapper waitTillOpened];
            if (mapper.isMapped) {
                [RSUtilities setNatTier:RSTierNoNatOrNatPmp];
            } else {
                [RSUtilities setNatTier:RSTierUdpHolePunching];
            }
            for (id delegate in delegates) {
                if ([delegate respondsToSelector:@selector(mapper:didMapWithSuccess:)]) {
                    [delegate mapper:mapper didMapWithSuccess:(mapper.isMapped)];
                }
            }
        });
    }
    started = YES;
}

+ (void)stop
{
    started = NO;
    for (PortMapper *mapper in mappers) {
        [mapper close];
    }
}

+ (NSString *)publicAddress
{
    return [PortMapper findPublicAddress];
}

+ (NSString *)privateAddress
{
    return [PortMapper localAddress];
}

+ (void)addDelegate:(id)delegate
{
    if (!delegates) {
        delegates = [NSMutableArray array];
    }
    if (![delegates containsObject:delegate]) {
        [delegates addObject:delegate];
    }
}

+ (void)addMapperWithPort:(UInt16)port
{
    if (!mappers) {
        mappers = [NSMutableArray array];
    }
    PortMapper *mapper = [RSPortMapper portMapperWithPort:port];
    if (![mappers containsObject:mapper]) {
        [mappers addObject:mapper];
    }
}

+ (PortMapper *)portMapperWithPort:(UInt16)port
{
    PortMapper *mapper = [[PortMapper alloc] initWithPort:port];
    mapper.mapTCP = NO;
    mapper.mapUDP = YES;
    return mapper;
}

- (void)portMappingChanged:(NSNotification *)aNotification {
    PortMapper *mapper = aNotification.object;
    if (started == YES && mapper.isMapped == NO) {
        for (id delegate in delegates) {
            if ([delegate respondsToSelector:@selector(mapper:didMapWithSuccess:)]) {
                [delegate mapper:mapper didMapWithSuccess:(mapper.isMapped)];
            }
        }
    }
    if ([RSUtilities natTier] == RSTierNoNatOrNatPmp && mapper.isMapped == NO) {
        //Mapper closed
        for (id delegate in delegates) {
            if ([delegate respondsToSelector:@selector(mapperDidClose:)]) {
                [delegate mapperDidClose:mapper];
            }
        }
    }
}

@end
