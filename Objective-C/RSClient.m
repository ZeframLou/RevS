//
//  RSClient.m
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

@interface RSClient () <RSMessengerDelegate,RSPortMapperDelegate>

@property (nonatomic,strong) NSTimer *keepAliveTimer;
@property (nonatomic,strong) RSMessenger *keepAliveMessenger;

@end

@implementation RSClient

@synthesize keepAliveTimer,keepAliveMessenger;

+ (RSClient *)sharedInstance
{
    static RSClient *sharedInstance;
    if (!sharedInstance) {
        sharedInstance = [[RSClient alloc]init];
        [RSMessenger registerMessageIdentifiers:@[@"IPLIST",@"JOIN",@"QUIT"] delegate:sharedInstance];
    }
    return sharedInstance;
}

+ (void)downloadIPList
{
    RSMessenger *message = [RSMessenger messengerWithPort:MESSAGE_PORT delegate:[RSClient sharedInstance]];
    [message sendServerMessage:[RSMessenger messageWithIdentifier:@"BOOTSTRAP" arguments:@[[RSUtilities deviceID],[RSUtilities publicIpAddress],[RSUtilities privateIpAddress]]] toServerAddress:SERVER_IP tag:0];
}

+ (void)join
{
    if ([[RSUtilities publicIpAddress] isEqualToString:[RSUtilities privateIpAddress]]) {
        [RSUtilities setNatTier:RSTierNoNatOrNatPmp];
        [RSClient sendJoinMessages];
    }
    else
    {
        [RSPortMapper addDelegate:[RSClient sharedInstance]];
        [RSPortMapper addMapperWithPort:MESSAGE_PORT];
        [RSPortMapper start];
    }
}

+ (void)quit
{
    NSInteger i = 0;
    for (NSString *ip in [RSUtilities localPublicIpList]) {
        NSString *publicIP = ip;
        NSString *privateIP = [[RSUtilities localPrivateIpList] objectAtIndex:i];
        RSMessenger *message = [RSMessenger messengerWithPort:MESSAGE_PORT delegate:[RSClient sharedInstance]];
        [message sendUdpMessage:[RSMessenger messageWithIdentifier:@"QUIT" arguments:@[[RSUtilities deviceID],[RSUtilities publicIpAddress]]] toHostWithPublicAddress:publicIP privateAddress:privateIP tag:0];
        i++;
    }

    [[RSClient sharedInstance]stopKeepAliveMessages];
    [RSPortMapper stop];
}

+ (void)sendJoinMessages
{
    if (![[NSFileManager defaultManager]fileExistsAtPath:IP_LIST_PATH]) {
        NSString *deviceHash = [RSUtilities hashFromString:[NSString stringWithFormat:@"%@,%@",[RSUtilities publicIpAddress],[RSUtilities privateIpAddress]]];
        [[NSUserDefaults standardUserDefaults]setObject:deviceHash forKey:@"deviceID"];
        [[NSUserDefaults standardUserDefaults]setObject:deviceHash forKey:@"lastIPHash"];
        [self downloadIPList];
    }
    else {
        NSArray *localPublicIPList = [RSUtilities localPublicIpList];
        NSArray *localPrivateIPList = [RSUtilities localPrivateIpList];
        [self initFiles];
        NSInteger i = 0;
        for (NSString *ip in localPublicIPList) {
            NSString *publicIP = ip;
            NSString *privateIP = [localPrivateIPList objectAtIndex:i];
            RSMessenger *message = [RSMessenger messengerWithPort:MESSAGE_PORT delegate:[RSClient sharedInstance]];
            [message sendUdpMessage:[RSMessenger messageWithIdentifier:@"JOIN" arguments:@[[RSUtilities deviceID],[RSUtilities publicIpAddress],[RSUtilities privateIpAddress]]] toHostWithPublicAddress:publicIP privateAddress:privateIP tag:0];
            i++;
        }

        if ([RSUtilities ipHasChanged]) {
            [RSUtilities updateIPHash];
            RSMessenger *message = [RSMessenger messengerWithPort:MESSAGE_PORT delegate:[RSClient sharedInstance]];
            [message sendServerMessage:[RSMessenger messageWithIdentifier:@"JOIN" arguments:@[[RSUtilities deviceID],[RSUtilities publicIpAddress],[RSUtilities privateIpAddress]]] toServerAddress:SERVER_IP tag:0];
        }
    }
}

+ (void)initFiles
{
    if (![[NSFileManager defaultManager]fileExistsAtPath:STORED_DATA_DIRECTORY]) {
        [[NSFileManager defaultManager]createDirectoryAtPath:STORED_DATA_DIRECTORY withIntermediateDirectories:YES attributes:nil error:nil];
    }
    if (![[NSFileManager defaultManager]fileExistsAtPath:PROB_INDEX_PATH]) {
        NSMutableArray *probArray = [NSMutableArray array];
        for (NSInteger i = 0; i < [RSUtilities localPublicIpList].count; i++) {
            [probArray addObject:[NSString stringWithFormat:@"%@,%@:%ld",[[RSUtilities localPublicIpList]objectAtIndex:i],[[RSUtilities localPrivateIpList]objectAtIndex:i],(unsigned long)INITIAL_PROB_INDEX]];
        }
        NSString *probIndexString = [probArray componentsJoinedByString:@";"];
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
    [RSClient sharedInstance].keepAliveMessenger = [RSMessenger messengerWithPort:MESSAGE_PORT delegate:[RSClient sharedInstance]];
    [keepAliveMessenger sendServerMessage:[RSMessenger messageWithIdentifier:@"ALIVE" arguments:@[]] toServerAddress:SERVER_IP tag:0];
}

#pragma mark - RSPortMapperDelegate

- (void)mapper:(PortMapper *)mapper didMapWithSuccess:(BOOL)success
{
    if (!success) {
        [[RSClient sharedInstance]startKeepAliveMessages];
    }
    [RSClient sendJoinMessages];
}

#pragma mark - RSMessageDelegate

- (void)messenger:(RSMessenger *)messenger didRecieveMessageWithIdentifier:(NSString *)identifier arguments:(NSArray *)arguments tag:(NSInteger)tag
{
    if ([identifier isEqualToString:@"IPLIST"]) {
        NSString *listString = [arguments lastObject];
        NSData *encryptedList = [NSData encryptString:listString withKey:MESSAGE_CODE];
        [encryptedList writeToFile:IP_LIST_PATH atomically:YES];
        NSArray *publicIpList = [RSUtilities localPublicIpList];
        NSArray *privateIpList = [RSUtilities localPrivateIpList];
        NSInteger i = 0;
        for (NSString *ip in publicIpList) {
            NSString *publicIP = ip;
            NSString *privateIP = [privateIpList objectAtIndex:i];
            RSMessenger *message = [RSMessenger messengerWithPort:MESSAGE_PORT delegate:[RSClient sharedInstance]];
            [message sendUdpMessage:[RSMessenger messageWithIdentifier:@"JOIN" arguments:@[[RSUtilities deviceID],[RSUtilities publicIpAddress],[RSUtilities privateIpAddress]]] toHostWithPublicAddress:publicIP privateAddress:privateIP tag:0];
            i++;
        }
        [RSClient initFiles];
    }
    else if ([identifier isEqualToString:@"JOIN"]) {
        NSString *deviceHash = [arguments objectAtIndex:0];
        NSString *publicIP = [arguments objectAtIndex:1];
        NSString *privateIP = [arguments objectAtIndex:2];
        NSString *dataString = [NSData decryptData:[NSData dataWithContentsOfFile:IP_LIST_PATH] withKey:FILE_CODE];
        NSMutableArray *dataArray;
        if (dataString.length == 0) {
            dataArray = [NSMutableArray array];
        }
        else
        {
            dataArray = [NSMutableArray arrayWithArray:[dataString componentsSeparatedByString:@";"]];
        }
        for (NSString *string in dataArray) {
            NSArray *array = [string componentsSeparatedByString:@"|"];
            NSString *hash = [array objectAtIndex:0];
            if ([deviceHash isEqualToString:hash]) {
                NSString *newDataString = [NSString stringWithFormat:@"%@|%@,%@|1",hash,publicIP,privateIP];
                [dataArray replaceObjectAtIndex:[dataArray indexOfObject:string] withObject:newDataString];
            }
        }
        if (![[RSUtilities localPublicIpList]containsObject:publicIP] && ![[RSUtilities localPrivateIpList]containsObject:privateIP]) {
            NSString *newDataString = [NSString stringWithFormat:@"%@|%@,%@|1",deviceHash,publicIP,privateIP];
            [dataArray addObject:newDataString];
            NSString *dataString = [NSData decryptData:[NSData dataWithContentsOfFile:PROB_INDEX_PATH] withKey:FILE_CODE];
            NSMutableArray *probArray;
            if (dataString.length == 0) {
                probArray = [NSMutableArray array];
            }
            else
            {
                probArray = [NSMutableArray arrayWithArray:[dataString componentsSeparatedByString:@";"]];
            }
            [probArray addObject:[NSString stringWithFormat:@"%@,%@:%ld",publicIP,privateIP,(unsigned long)INITIAL_PROB_INDEX]];
            [[NSData encryptString:[probArray componentsJoinedByString:@";"] withKey:FILE_CODE] writeToFile:PROB_INDEX_PATH atomically:YES];
        }
        NSString *ipListString = [dataArray componentsJoinedByString:@";"];
        [[NSData encryptString:ipListString withKey:FILE_CODE]writeToFile:IP_LIST_PATH atomically:YES];
    }
    else if ([identifier isEqualToString:@"QUIT"]) {
        NSString *deviceHash = [arguments objectAtIndex:0];
        NSString *publicIP = [arguments objectAtIndex:1];
        NSString *privateIP = [arguments objectAtIndex:2];
        NSString *dataString = [NSData decryptData:[NSData dataWithContentsOfFile:IP_LIST_PATH] withKey:FILE_CODE];
        NSMutableArray *dataArray;
        if (dataString.length == 0) {
            dataArray = [NSMutableArray array];
        }
        else
        {
            dataArray = [NSMutableArray arrayWithArray:[dataString componentsSeparatedByString:@";"]];
        }
        for (NSString *string in dataArray) {
            NSArray *array = [string componentsSeparatedByString:@"|"];
            NSString *hash = [array objectAtIndex:0];
            if ([deviceHash isEqualToString:hash]) {
                NSString *newDataString = [NSString stringWithFormat:@"%@|%@,%@|0",hash,publicIP,privateIP];
                [dataArray replaceObjectAtIndex:[dataArray indexOfObject:string] withObject:newDataString];
            }
        }
        NSString *ipListString = [dataArray componentsJoinedByString:@";"];
        [[NSData encryptString:ipListString withKey:FILE_CODE]writeToFile:IP_LIST_PATH atomically:YES];
    }
}

@end
