//
//  RSNodeManage.m
//  RevS
//
//  Created by Zebang Liu on 13-8-1.
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

@interface RSNodeManage () <RSIPListDelegate,RSMessagerDelegate>

@end

@implementation RSNodeManage

+ (RSNodeManage *)sharedInstance
{
    static RSNodeManage *sharedInstance;
    if (!sharedInstance) {
        sharedInstance = [[RSNodeManage alloc]init];
    }
    return sharedInstance;
}

- (void)downloadIPList
{
    RSUtilities *obj = [[RSUtilities alloc]init];
    obj.delegate = self;
    [obj remoteIpListInString];
}

- (void)join
{
    //[[RSListener sharedListener]start];
    NSArray *localIPList = [RSUtilities localIpList];
    if (localIPList.count == 0) {
        [self downloadIPList];
    }
    else {
        [self initFiles];
        for (NSString *ip in localIPList) {
            RSMessager *message = [RSMessager messagerWithPort:MESSAGE_PORT];
            [message addDelegate:self];
            [message sendTcpMessage:[NSString stringWithFormat:@"JOIN_%@",[RSUtilities getLocalIPAddress]] toHost:ip tag:0];
        }
    }
}

- (void)quit
{
    for (NSString *ip in [RSUtilities localIpList]) {
        RSMessager *message = [RSMessager messagerWithPort:MESSAGE_PORT];
        [message addDelegate:self];
        [message sendTcpMessage:[NSString stringWithFormat:@"QUIT_%@",[RSUtilities getLocalIPAddress]] toHost:ip tag:0];
    }
}

- (void)initFiles
{
    if (![[NSFileManager defaultManager]fileExistsAtPath:STORED_DATA_DIRECTORY]) {
        [[NSFileManager defaultManager]createDirectoryAtPath:STORED_DATA_DIRECTORY withIntermediateDirectories:YES attributes:nil error:nil];
    }
    if (![[NSFileManager defaultManager]fileExistsAtPath:PROB_INDEX_PATH]) {
        NSMutableArray *probArray = [NSMutableArray array];
        for (NSUInteger i = 0; i < NEIGHBOUR_COUNT; i++) {
            if (i < [RSUtilities localIpList].count) {
                [probArray addObject:[NSString stringWithFormat:@"%@:%d",[[RSUtilities localIpList]objectAtIndex:i],INITIAL_PROB_INDEX]];
            }
        }
        NSString *probIndexString = [probArray componentsJoinedByString:@","];
        NSData *encryptedString = [NSData encryptString:probIndexString withKey:CODE];
        [encryptedString writeToFile:PROB_INDEX_PATH atomically:YES];
    }
}

#pragma mark - RSIPListDelegate

- (void)didRecieveRemoteIPList:(id)list
{
    if ([list isMemberOfClass:[NSString class]]) {
        NSData *encryptedList = [NSData encryptString:list withKey:CODE];
        [encryptedList writeToFile:IP_LIST_PATH atomically:YES];
        NSArray *ipList = [list componentsSeparatedByString:@","];
        for (NSString *ip in ipList) {
            RSMessager *message = [RSMessager messagerWithPort:MESSAGE_PORT];
            [message addDelegate:self];
            [message sendTcpMessage:[NSString stringWithFormat:@"JOIN_%@",[RSUtilities getLocalIPAddress]] toHost:ip tag:0];
        }
        [self initFiles];
    }
}

@end
