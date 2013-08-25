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

@interface RSNodeManage () <RSMessengerDelegate>

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

+ (void)downloadIPList
{
    RSMessenger *message = [RSMessenger messengerWithPort:MESSAGE_PORT];
    [message addDelegate:[RSNodeManage sharedInstance]];
    [message sendTcpMessage:@"IPLIST" toHost:SERVER_IP tag:0];
}

+ (void)join
{
    NSArray *localIPList = [RSUtilities localIpList];
    if (localIPList.count == 0) {
        [self downloadIPList];
    }
    else {
        [self initFiles];
        for (NSString *ip in localIPList) {
            RSMessenger *message = [RSMessenger messengerWithPort:MESSAGE_PORT];
            [message addDelegate:[RSNodeManage sharedInstance]];
            [message sendTcpMessage:[RSMessenger messageWithIdentifier:@"JOIN" arguments:@[[RSUtilities getLocalIPAddress]]] toHost:ip tag:0];
        }
    }
}

+ (void)quit
{
    for (NSString *ip in [RSUtilities localIpList]) {
        RSMessenger *message = [RSMessenger messengerWithPort:MESSAGE_PORT];
        [message addDelegate:[RSNodeManage sharedInstance]];
        [message sendTcpMessage:[RSMessenger messageWithIdentifier:@"QUIT" arguments:@[[RSUtilities getLocalIPAddress]]] toHost:ip tag:0];
    }
}

+ (void)initFiles
{
    if (![[NSFileManager defaultManager]fileExistsAtPath:STORED_DATA_DIRECTORY]) {
        [[NSFileManager defaultManager]createDirectoryAtPath:STORED_DATA_DIRECTORY withIntermediateDirectories:YES attributes:nil error:nil];
    }
    if (![[NSFileManager defaultManager]fileExistsAtPath:PROB_INDEX_PATH]) {
        NSMutableArray *probArray = [NSMutableArray array];
        for (NSUInteger i = 0; i < NEIGHBOR_COUNT; i++) {
            if (i < [RSUtilities localIpList].count) {
                [probArray addObject:[NSString stringWithFormat:@"%@:%ld",[[RSUtilities localIpList]objectAtIndex:i],(unsigned long)INITIAL_PROB_INDEX]];
            }
        }
        NSString *probIndexString = [probArray componentsJoinedByString:@","];
        NSData *encryptedString = [NSData encryptString:probIndexString withKey:MESSAGE_CODE];
        [encryptedString writeToFile:PROB_INDEX_PATH atomically:YES];
    }
}

#pragma mark - RSMessageDelegate

- (void)messenger:(RSMessenger *)messenger didRecieveData:(NSData *)data tag:(NSInteger)tag;
{
    NSString *messageString = [NSData decryptData:data withKey:MESSAGE_CODE];
    NSString *messageType = [RSMessenger identifierOfMessage:messageString];
    NSArray *messageArguments = [RSMessenger argumentsOfMessage:messageString];
    if ([messageType isEqualToString:@"IPL"]) {
        NSString *listString = [messageArguments lastObject];
        //The ip list is formatted like this:
        //Address1,isOnline;Address2,isOnline;Address3,isOnline...
        //"isOnline"is a BOOL value.
        NSData *encryptedList = [NSData encryptString:listString withKey:MESSAGE_CODE];
        [encryptedList writeToFile:IP_LIST_PATH atomically:YES];
        NSArray *ipList = [RSUtilities localIpList];
        for (NSString *ip in ipList) {
            RSMessenger *message = [RSMessenger messengerWithPort:MESSAGE_PORT];
            [message addDelegate:self];
            [message sendTcpMessage:[RSMessenger messageWithIdentifier:@"JOIN" arguments:@[[RSUtilities getLocalIPAddress]]] toHost:ip tag:0];
        }
        RSMessenger *message = [RSMessenger messengerWithPort:MESSAGE_PORT];
        [message addDelegate:self];
        [message sendTcpMessage:[RSMessenger messageWithIdentifier:@"JOIN" arguments:@[[RSUtilities getLocalIPAddress]]] toHost:SERVER_IP tag:0];
        [RSNodeManage initFiles];
    }
}

@end
