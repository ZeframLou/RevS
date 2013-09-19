//
//  RSPortMapper.m
//  RevS
//
//  Created by lzbdd on 13-9-15.
//  Copyright (c) 2013年 lzbdd. All rights reserved.
//

#import "RevS.h"
#import "PortMapper.h"

static NSMutableArray *mappers;
static NSMutableArray *delegates;
static BOOL started;

@interface RSPortMapper ()

@end

@implementation RSPortMapper

+ (void)start
{
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(portMappingChanged:)
                                                 name: PortMapperChangedNotification
                                               object: nil];
    dispatch_async(dispatch_queue_create("waitMappingResult", NULL), ^{
        for (PortMapper *mapper in mappers) {
            [mapper open];
        }
    });
    started = YES;
}

+ (void)stop
{
    for (PortMapper *mapper in mappers) {
        [mapper close];
    }
    started = NO;
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
        [mapper open];
        [mappers addObject:mapper];
    }
}

+ (PortMapper *)portMapperWithPort:(UInt16)port
{
    PortMapper *mapper = [[PortMapper alloc] initWithPort:port];
    mapper.mapTCP = YES;
    mapper.mapUDP = YES;
    return mapper;
}

+ (void)portMappingChanged:(NSNotification *)aNotification {
    PortMapper *mapper = aNotification.object;
    if (mapper.isMapped) {
        NAT_TIER = RSTierNoNatOrNatPmp;
    } else {
        NAT_TIER = RSTierUdpHolePunching;
    }
    for (id delegate in delegates) {
        if ([delegate respondsToSelector:@selector(mapper:didMapWithSuccess:)]) {
            [delegate mapper:mapper didMapWithSuccess:(mapper.isMapped)];
        }
    }
}

@end
