//
//  RSServer.m
//  RevS
//
//  Created by lzbdd on 13-9-29.
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

static RSMessenger *messenger;
static NSMutableArray *delegates;

@interface RSServer () <RSMessengerDelegate>

@property (nonatomic) BOOL started;

@end

@implementation RSServer

@synthesize started;

+ (RSServer *)sharedInstance
{
    static RSServer *sharedInstance;
    if (!sharedInstance) {
        sharedInstance = [[RSServer alloc]init];
    }
    return sharedInstance;
}

+ (void)start
{
    if (!messenger) {
        [RSPortMapper addMapperWithPort:MESSAGE_PORT];
        [RSPortMapper start];
        [RSUtilities setNatTier:RSTierNoNatOrNatPmp];
        messenger = [RSMessenger messengerWithPort:MESSAGE_PORT delegate:[RSServer sharedInstance]];
        [RSMessenger registerMessageIdentifiers:@[@"BOOTSTRAP",@"JOIN",@"RELAY",@"COMSRVR"] delegate:[RSServer sharedInstance]];
        [RSServer initFiles];
    }
    [RSServer sharedInstance].started = YES;
}

+ (void)stop
{
    [RSPortMapper stop];
    [messenger closeConnection];
    [RSServer sharedInstance].started = NO;
}

+ (void)listenForMessagesWithIdentifiers:(NSArray *)identifiers
{
    [RSMessenger registerMessageIdentifiers:identifiers delegate:[RSServer sharedInstance]];
}

+ (BOOL)isStarted
{
    return [RSServer sharedInstance].started;
}

+ (void)initFiles
{
    if (![[NSFileManager defaultManager]fileExistsAtPath:IP_LIST_PATH]) {
        [[NSFileManager defaultManager]createFileAtPath:IP_LIST_PATH contents:nil attributes:nil];
    }
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

- (void)messenger:(RSMessenger *)messenger didRecieveMessageWithIdentifier:(NSString *)identifier arguments:(NSArray *)arguments tag:(NSInteger)tag
{
    if ([identifier isEqualToString:@"BOOTSTRAP"]) {
        NSString *deviceID = [arguments objectAtIndex:0];
        NSString *publicIp = [arguments objectAtIndex:1];
        NSString *privateIp = [arguments objectAtIndex:2];
        
        NSMutableArray *clientList;
        NSData *fileData = [NSData dataWithContentsOfFile:IP_LIST_PATH];
        if (fileData.length == 0) {
            clientList = [NSMutableArray array];
        }
        else
        {
            clientList = [NSMutableArray arrayWithArray:[[NSData decryptData:[NSData dataWithContentsOfFile:IP_LIST_PATH] withKey:FILE_CODE] componentsSeparatedByString:@";"]];
        }
        
        //Randomly select a bunch of neighbors
        NSMutableArray *selectedNeighborList = [NSMutableArray array];
        NSInteger remaining = NEIGHBOR_COUNT;
        if (clientList.count >= NEIGHBOR_COUNT) {
            while (remaining > 0) {
                NSString *neighbor = [clientList objectAtIndex:arc4random() % clientList.count];
                if (![selectedNeighborList containsObject:neighbor] && ![neighbor isEqualToString:[NSString stringWithFormat:@"%@|%@,%@|1",deviceID,publicIp,privateIp]]) {
                    [selectedNeighborList addObject:neighbor];
                    remaining--;
                }
            }
        }
        NSString *neighborListString = [selectedNeighborList componentsJoinedByString:@";"];
        
        //Send it
        RSMessenger *messenger = [RSMessenger messengerWithPort:MESSAGE_PORT delegate:[RSServer sharedInstance]];
        NSString *messageString = [RSMessenger messageWithIdentifier:@"IPLIST" arguments:@[neighborListString]];
        [messenger sendUdpMessage:messageString toHostWithPublicAddress:publicIp privateAddress:privateIp tag:0];
        
        //Save the clent's info
        if (![clientList containsObject:[NSString stringWithFormat:@"%@|%@,%@|1",deviceID,publicIp,privateIp]]) {
            [clientList addObject:[NSString stringWithFormat:@"%@|%@,%@|1",deviceID,publicIp,privateIp]];
            [[NSData encryptString:[clientList componentsJoinedByString:@";"] withKey:FILE_CODE] writeToFile:IP_LIST_PATH atomically:YES];
        }
    }
    else if ([identifier isEqualToString:@"JOIN"]) {
        NSString *deviceID = [arguments objectAtIndex:0];
        NSString *publicIp = [arguments objectAtIndex:1];
        NSString *privateIp = [arguments objectAtIndex:2];
        
        NSMutableArray *clientList;
        NSData *fileData = [NSData dataWithContentsOfFile:IP_LIST_PATH];
        if (fileData.length == 0) {
            clientList = [NSMutableArray array];
        }
        else
        {
            clientList = [NSMutableArray arrayWithArray:[[NSData decryptData:[NSData dataWithContentsOfFile:IP_LIST_PATH] withKey:FILE_CODE] componentsSeparatedByString:@";"]];
        }
        
        NSInteger i = 0;
        for (NSString *client in clientList) {
            NSArray *array = [client componentsSeparatedByString:@"|"];
            NSString *clientHash = [array objectAtIndex:0];
            if ([deviceID isEqualToString:clientHash]) {
                NSString *infoString = [NSString stringWithFormat:@"%@|%@,%@|1",deviceID,publicIp,privateIp];
                [clientList replaceObjectAtIndex:i withObject:infoString];
                break;
            }
            i++;
        }
        [[NSData encryptString:[clientList componentsJoinedByString:@";"] withKey:FILE_CODE] writeToFile:IP_LIST_PATH atomically:YES];
    }
    else if ([identifier isEqualToString:@"RELAY"]) {
        NSString *dataString = [arguments objectAtIndex:0];
        NSString *publicIp = [arguments objectAtIndex:1];
        NSString *privateIp = [arguments objectAtIndex:2];
        
        //Relay the message
        RSMessenger *messenger = [RSMessenger messengerWithPort:MESSAGE_PORT delegate:[RSServer sharedInstance]];
        [messenger sendUdpMessage:dataString toHostWithPublicAddress:publicIp privateAddress:privateIp tag:0];
    }
    else if ([identifier isEqualToString:@"COMSRVR"]) {
        NSString *requesterPublicIp = [arguments objectAtIndex:0];
        NSString *requesterPrivateIp = [arguments objectAtIndex:1];
        NSString *destinationPublicIp = [arguments objectAtIndex:2];
        NSString *destinationPrivateIp = [arguments objectAtIndex:3];
        
        //Contact clients
        RSMessenger *messenger = [RSMessenger messengerWithPort:MESSAGE_PORT delegate:[RSServer sharedInstance]];
        NSString *messageString = [RSMessenger messageWithIdentifier:@"COMCLNT" arguments:@[requesterPublicIp,requesterPrivateIp]];
        [messenger sendUdpMessage:messageString toHostWithPublicAddress:destinationPublicIp privateAddress:destinationPrivateIp tag:0];
        messageString = [RSMessenger messageWithIdentifier:@"COMCLNT" arguments:@[destinationPublicIp,destinationPrivateIp]];
        [messenger sendUdpMessage:messageString toHostWithPublicAddress:requesterPublicIp privateAddress:requesterPrivateIp tag:0];
    }
    else {
        for (id delegate in delegates) {
            if ([delegate respondsToSelector:@selector(serverDidRecieveMessageWithIdentifier:arguments:)]) {
                [delegate serverDidRecieveMessageWithIdentifier:identifier arguments:arguments];
            }
        }
    }
}

@end
