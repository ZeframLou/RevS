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

@interface RSNodeManage () <RSMessengerDelegate,RSPortMapperDelegate>

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
    [message sendServerMessage:[RSMessenger messageWithIdentifier:@"BOOTSTRAP" arguments:@[[RSUtilities deviceID],[RSUtilities publicIpAddress]]] toServerAddress:SERVER_IP tag:0];
}

+ (void)join
{
    if ([[RSUtilities publicIpAddress] isEqualToString:[RSUtilities privateIpAddress]]) {
        NAT_TIER = RSTierNoNatOrNatPmp;
    }
    else
    {
        [RSPortMapper addDelegate:[RSNodeManage sharedInstance]];
        [RSPortMapper addMapperWithPort:MESSAGE_PORT];
        [RSPortMapper start];
    }
}

+ (void)quit
{
    for (NSString *ip in [RSUtilities localIpList]) {
        RSMessenger *message = [RSMessenger messengerWithPort:MESSAGE_PORT];
        [message addDelegate:[RSNodeManage sharedInstance]];
        [message sendServerMessage:[RSMessenger messageWithIdentifier:@"QUIT" arguments:@[[RSUtilities deviceID],[RSUtilities publicIpAddress]]] toServerAddress:SERVER_IP tag:0];
    }
    [[RSNodeManage sharedInstance]stopKeepAliveMessages];
    [RSPortMapper stop];
}

+ (void)sendJoinMessages
{
    NSArray *localIPList = [RSUtilities localIpList];
    if (localIPList.count == 0) {
        NSString *deviceHash = [RSUtilities hashFromString:[RSUtilities publicIpAddress]];
        [[NSUserDefaults standardUserDefaults]setObject:deviceHash forKey:@"deviceID"];
        [[NSUserDefaults standardUserDefaults]setObject:deviceHash forKey:@"lastIPHash"];
        [self downloadIPList];
    }
    else {
        [self initFiles];
        for (NSString *ip in localIPList) {
            RSMessenger *message = [RSMessenger messengerWithPort:MESSAGE_PORT];
            [message addDelegate:[RSNodeManage sharedInstance]];
            [message sendUdpMessage:[RSMessenger messageWithIdentifier:@"JOIN" arguments:@[[RSUtilities deviceID],[RSUtilities publicIpAddress]]] toHost:ip tag:0];
        }
        if ([RSUtilities ipHasChanged]) {
            [RSUtilities updateIPHash];
        }
        RSMessenger *message = [RSMessenger messengerWithPort:MESSAGE_PORT];
        [message addDelegate:[RSNodeManage sharedInstance]];
        [message sendServerMessage:[RSMessenger messageWithIdentifier:@"JOIN&GET_NEIGHBOR_STATUS" arguments:@[[RSUtilities deviceID],[RSUtilities publicIpAddress]]] toServerAddress:SERVER_IP tag:0];
    }
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

#pragma mark - RSPortMapperDelegate

- (void)mapperDidMapWithSuccess:(BOOL)success
{
    if (!success) {
        [[RSNodeManage sharedInstance]startKeepAliveMessages];
    }
    [RSNodeManage sendJoinMessages];
}

#pragma mark - RSMessageDelegate

- (void)messenger:(RSMessenger *)messenger didRecieveMessageWithIdentifier:(NSString *)identifier arguments:(NSArray *)arguments tag:(NSInteger)tag
{
    if ([identifier isEqualToString:@"IPLIST"]) {
        if ([RSUtilities localIpList].count == 0) {
            NSString *listString = [arguments lastObject];
            NSData *encryptedList = [NSData encryptString:listString withKey:MESSAGE_CODE];
            [encryptedList writeToFile:IP_LIST_PATH atomically:YES];
            NSArray *ipList = [RSUtilities localIpList];
            for (NSString *ip in ipList) {
                RSMessenger *message = [RSMessenger messengerWithPort:MESSAGE_PORT];
                [message addDelegate:[RSNodeManage sharedInstance]];
                [message sendUdpMessage:[RSMessenger messageWithIdentifier:@"JOIN" arguments:@[[RSUtilities deviceID],[RSUtilities publicIpAddress]]] toHost:ip tag:0];
            }
            RSMessenger *message = [RSMessenger messengerWithPort:MESSAGE_PORT];
            [message addDelegate:self];
            [message sendServerMessage:[RSMessenger messageWithIdentifier:@"JOIN" arguments:@[[RSUtilities deviceID],[RSUtilities publicIpAddress]]] toServerAddress:SERVER_IP tag:0];
            [RSNodeManage initFiles];
        }
        else {
            NSString *listString = [arguments lastObject];
            NSData *encryptedList = [NSData encryptString:listString withKey:MESSAGE_CODE];
            [encryptedList writeToFile:IP_LIST_PATH atomically:YES];
        }
    }
    else if ([identifier isEqualToString:@"JOIN"]) {
        NSString *deviceHash = [arguments objectAtIndex:0];
        NSString *publicIP = [arguments objectAtIndex:1];
        NSString *dataString = [NSData decryptData:[NSData dataWithContentsOfFile:IP_LIST_PATH] withKey:FILE_CODE];
        NSMutableArray *dataArray = [NSMutableArray arrayWithArray:[dataString componentsSeparatedByString:@";"]];
        for (NSString *string in dataArray) {
            NSArray *array = [string componentsSeparatedByString:@"|"];
            NSString *hash = [array objectAtIndex:0];
            if ([deviceHash isEqualToString:hash]) {
                NSString *newDataString = [NSString stringWithFormat:@"%@|%@|1",hash,publicIP];
                [dataArray replaceObjectAtIndex:[dataArray indexOfObject:string] withObject:newDataString];
            }
        }
        NSString *ipListString = [dataArray componentsJoinedByString:@";"];
        [[NSData encryptString:ipListString withKey:FILE_CODE]writeToFile:IP_LIST_PATH atomically:YES];
    }
    else if ([identifier isEqualToString:@"QUIT"]) {
        NSString *deviceHash = [arguments objectAtIndex:0];
        NSString *publicIP = [arguments objectAtIndex:1];
        NSString *dataString = [NSData decryptData:[NSData dataWithContentsOfFile:IP_LIST_PATH] withKey:FILE_CODE];
        NSMutableArray *dataArray = [NSMutableArray arrayWithArray:[dataString componentsSeparatedByString:@";"]];
        for (NSString *string in dataArray) {
            NSArray *array = [string componentsSeparatedByString:@"|"];
            NSString *hash = [array objectAtIndex:0];
            if ([deviceHash isEqualToString:hash]) {
                NSString *newDataString = [NSString stringWithFormat:@"%@|%@|0",hash,publicIP];
                [dataArray replaceObjectAtIndex:[dataArray indexOfObject:string] withObject:newDataString];
            }
        }
        NSString *ipListString = [dataArray componentsJoinedByString:@";"];
        [[NSData encryptString:ipListString withKey:FILE_CODE]writeToFile:IP_LIST_PATH atomically:YES];
    }
}

@end
