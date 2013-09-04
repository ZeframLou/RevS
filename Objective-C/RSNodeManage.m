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

@property (nonatomic,strong) NSTimer *keepAliveTimer;
@property (nonatomic,strong) RSMessenger *keepAliveMessenger;

@end

@implementation RSNodeManage

@synthesize keepAliveTimer,keepAliveMessenger;

+ (RSNodeManage *)sharedInstance
{
    static RSNodeManage *sharedInstance;
    if (!sharedInstance) {
        sharedInstance = [[RSNodeManage alloc]init];
        sharedInstance.keepAliveMessenger = [RSMessenger messengerWithPort:MESSAGE_PORT];
    }
    return sharedInstance;
}

+ (void)downloadIPList
{
    RSMessenger *message = [RSMessenger messengerWithPort:MESSAGE_PORT];
    [message addDelegate:[RSNodeManage sharedInstance]];
    [message sendServerMessage:[RSMessenger messageWithIdentifier:@"BOOTSTRAP" arguments:@[[RSUtilities deviceID],[RSUtilities publicIpAddress],[RSUtilities privateIpAddress]]] toServerAddress:SERVER_IP tag:0];
}

+ (void)join
{
    NSArray *localIPList = [RSUtilities localIpList];
    if (localIPList.count == 0) {
        NSString *deviceHash = [RSUtilities hashFromString:[NSString stringWithFormat:@"%@|%@",[RSUtilities publicIpAddress],[RSUtilities privateIpAddress]]];
        [[NSUserDefaults standardUserDefaults]setObject:deviceHash forKey:@"deviceID"];
        [[NSUserDefaults standardUserDefaults]setObject:deviceHash forKey:@"lastIPHash"];
        [self downloadIPList];
    }
    else {
        [self initFiles];
        for (NSString *string in localIPList) {
            NSString *publicAddress = [RSUtilities publicIpInString:string];
            NSString *privateAddress = [RSUtilities privateIpInString:string];
            RSMessenger *message = [RSMessenger messengerWithPort:MESSAGE_PORT];
            [message addDelegate:[RSNodeManage sharedInstance]];
            [message sendUdpMessage:[RSMessenger messageWithIdentifier:@"JOIN" arguments:@[[RSUtilities deviceID],[RSUtilities publicIpAddress],[RSUtilities privateIpAddress]]] toHostWithPublicAddress:publicAddress privateAddress:privateAddress tag:0];
        }
        if ([RSUtilities ipHasChanged]) {
            [RSUtilities updateIPHash];
            RSMessenger *message = [RSMessenger messengerWithPort:MESSAGE_PORT];
            [message addDelegate:[RSNodeManage sharedInstance]];
            [message sendServerMessage:[RSMessenger messageWithIdentifier:@"JOIN" arguments:@[[RSUtilities deviceID],[RSUtilities publicIpAddress],[RSUtilities privateIpAddress]]] toServerAddress:SERVER_IP tag:0];
        }
    }
    [[RSNodeManage sharedInstance]startKeepAliveMessages];
}

+ (void)quit
{
    for (NSString *ip in [RSUtilities localIpList]) {
        RSMessenger *message = [RSMessenger messengerWithPort:MESSAGE_PORT];
        [message addDelegate:[RSNodeManage sharedInstance]];
        [message sendServerMessage:[RSMessenger messageWithIdentifier:@"QUIT" arguments:@[[RSUtilities deviceID],[RSUtilities publicIpAddress],[RSUtilities privateIpAddress]]] toServerAddress:SERVER_IP tag:0];
    }
    [[RSNodeManage sharedInstance]stopKeepAliveMessages];
}

+ (void)initFiles
{
    if (![[NSFileManager defaultManager]fileExistsAtPath:STORED_DATA_DIRECTORY]) {
        [[NSFileManager defaultManager]createDirectoryAtPath:STORED_DATA_DIRECTORY withIntermediateDirectories:YES attributes:nil error:nil];
    }
    if (![[NSFileManager defaultManager]fileExistsAtPath:PROB_INDEX_PATH]) {
        NSMutableArray *probArray = [NSMutableArray array];
        for (NSInteger i = 0; i < NEIGHBOR_COUNT; i++) {
            if (i < [RSUtilities localIpList].count) {
                [probArray addObject:[NSString stringWithFormat:@"%@:%ld",[[RSUtilities localIpList]objectAtIndex:i],(unsigned long)INITIAL_PROB_INDEX]];
            }
        }
        NSString *probIndexString = [probArray componentsJoinedByString:@"/"];
        NSData *encryptedString = [NSData encryptString:probIndexString withKey:MESSAGE_CODE];
        [encryptedString writeToFile:PROB_INDEX_PATH atomically:YES];
    }
}

- (void)startKeepAliveMessages
{
    keepAliveTimer = [NSTimer scheduledTimerWithTimeInterval:KEEP_ALIVE_INTERVAL target:self selector:@selector(sendKeepAliveMessage) userInfo:nil repeats:YES];
}

- (void)stopKeepAliveMessages
{
    [keepAliveTimer invalidate];
}

- (void)sendKeepAliveMessage
{
    [keepAliveMessenger sendServerMessage:[RSMessenger messageWithIdentifier:@"ALIVE" arguments:@[]] toServerAddress:SERVER_IP tag:0];
}

#pragma mark - RSMessageDelegate

- (void)messenger:(RSMessenger *)messenger didRecieveMessageWithIdentifier:(NSString *)identifier arguments:(NSArray *)arguments tag:(NSInteger)tag
{
    if ([identifier isEqualToString:@"IPLIST"]) {
        NSString *listString = [arguments lastObject];
        NSData *encryptedList = [NSData encryptString:listString withKey:MESSAGE_CODE];
        [encryptedList writeToFile:IP_LIST_PATH atomically:YES];
        NSArray *ipList = [RSUtilities localIpList];
        for (NSString *string in ipList) {
            NSString *publicAddress = [RSUtilities publicIpInString:string];
            NSString *privateAddress = [RSUtilities privateIpInString:string];
            RSMessenger *message = [RSMessenger messengerWithPort:MESSAGE_PORT];
            [message addDelegate:[RSNodeManage sharedInstance]];
            [message sendUdpMessage:[RSMessenger messageWithIdentifier:@"JOIN" arguments:@[[RSUtilities deviceID],[RSUtilities publicIpAddress],[RSUtilities privateIpAddress]]] toHostWithPublicAddress:publicAddress privateAddress:privateAddress tag:0];
        }
        RSMessenger *message = [RSMessenger messengerWithPort:MESSAGE_PORT];
        [message addDelegate:self];
        [message sendServerMessage:[RSMessenger messageWithIdentifier:@"JOIN" arguments:@[[RSUtilities deviceID],[RSUtilities publicIpAddress],[RSUtilities privateIpAddress]]] toServerAddress:SERVER_IP tag:0];
        [RSNodeManage initFiles];
    }
}

@end
