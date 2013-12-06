//
//  RSUpload.m
//  RevS
//
//  Created by Zebang Liu on 13-8-1.
//  Copyright (c) 2013 Zebang Liu. All rights reserved.
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

@interface RSUpload () <RSMessengerDelegate>

@property (nonatomic,strong) NSMutableArray *delegates;

@end

@implementation RSUpload

@synthesize delegates;

+ (RSUpload *)sharedInstance
{
    static RSUpload *sharedInstance;
    if (!sharedInstance) {
        sharedInstance = [[RSUpload alloc]init];
        sharedInstance.delegates = [NSMutableArray array];
        [RSMessenger registerMessageIdentifiers:@[@"UP_REQ",@"UP_READY",@"U_FILE_DATA"] delegate:sharedInstance];
    }
    return sharedInstance;
}

+ (void)uploadFile:(NSString *)fileName
{
    NSArray *contactPublicIpList = [RSUtilities onlineNeighborsPublicIpList];
    NSArray *contactPrivateIpList = [RSUtilities onlineNeighborsPrivateIpList];

    for (NSInteger i = 0; i < K_UPLOAD; i++) {
        if (i < contactPublicIpList.count) {
            NSString *publicAddress = [contactPublicIpList objectAtIndex:i];
            NSString *privateAddress = [contactPrivateIpList objectAtIndex:i];
            NSString *messageString = [RSMessenger messageWithIdentifier:@"UP_REQ" arguments:@[fileName,[RSUtilities publicIpAddress],[RSUtilities privateIpAddress],[NSString stringWithFormat:@"%ld",(unsigned long)TTL]]];
            RSMessenger *message = [RSMessenger messengerWithPort:MESSAGE_PORT delegate:[RSUpload sharedInstance]];
            [message sendUdpMessage:messageString toHostWithPublicAddress:publicAddress privateAddress:privateAddress tag:0];
        }
    }
}

+ (void)uploadFile:(NSString *)fileName toPublicAddress:(NSString *)publicAddress privateAddress:(NSString *)privateAddress
{
    NSString *messageString = [RSMessenger messageWithIdentifier:@"U_FILE_DATA" arguments:@[fileName,[NSData decryptData:[NSData dataWithContentsOfFile:[STORED_DATA_DIRECTORY stringByAppendingString:fileName]] withKey:FILE_CODE],@"0",[RSUtilities publicIpAddress],[RSUtilities privateIpAddress]]];
    RSMessenger *message = [RSMessenger messengerWithPort:MESSAGE_PORT delegate:[RSUpload sharedInstance]];
    [message sendUdpMessage:messageString toHostWithPublicAddress:publicAddress privateAddress:privateAddress tag:0];
}

+ (void)addDelegate:(id <RSUploadDelegate>)delegate
{
    if (![[RSUpload sharedInstance].delegates containsObject:delegate]) {
        [[RSUpload sharedInstance].delegates addObject:delegate];
    }
}

- (void)messenger:(RSMessenger *)messenger didRecieveMessageWithIdentifier:(NSString *)identifier arguments:(NSArray *)arguments tag:(NSInteger)tag
{
    if ([identifier isEqualToString:@"UP_REQ"])
    {
        NSString *fileName = [arguments objectAtIndex:0];
        NSString *fileOwnerPublicIP = [arguments objectAtIndex:1];
        NSString *fileOwnerPrivateIP = [arguments objectAtIndex:2];
        NSInteger timeToLive = [[arguments objectAtIndex:3] integerValue];
        RSMessenger *message = [RSMessenger messengerWithPort:MESSAGE_PORT delegate:self];
        [message sendUdpMessage:[RSMessenger messageWithIdentifier:@"UP_READY" arguments:@[fileName,[RSUtilities publicIpAddress],[RSUtilities privateIpAddress],[NSString stringWithFormat:@"%ld",(unsigned long)timeToLive]]] toHostWithPublicAddress:fileOwnerPublicIP privateAddress:fileOwnerPrivateIP tag:0];
    }
    else if ([identifier isEqualToString:@"UP_READY"])
    {
        NSString *fileName = [arguments objectAtIndex:0];
        NSString *requesterPublicIP = [arguments objectAtIndex:1];
        NSString *requesterPrivateIP = [arguments objectAtIndex:2];
        NSInteger timeToLive = [[arguments objectAtIndex:3] integerValue];
        NSData *data = [NSData dataWithContentsOfFile:[NSString stringWithFormat:@"%@%@",STORED_DATA_DIRECTORY,fileName]];
        NSString *dataString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSString *string = [RSMessenger messageWithIdentifier:@"U_FILE_DATA" arguments:@[fileName,dataString,[NSString stringWithFormat:@"%ld",(unsigned long)timeToLive],requesterPublicIP,requesterPrivateIP]];
        RSMessenger *message = [RSMessenger messengerWithPort:MESSAGE_PORT delegate:self];
        [message sendUdpMessage:string toHostWithPublicAddress:requesterPublicIP privateAddress:requesterPrivateIP tag:0];
        for (id delegate in delegates) {
            if ([delegate respondsToSelector:@selector(didUploadFile:)]) {
                [delegate didUploadFile:fileName toPublicAddress:requesterPublicIP privateAddress:requesterPrivateIP];
            }
        }
    }
    else if ([identifier isEqualToString:@"U_FILE_DATA"]) {
        NSString *fileName = [arguments objectAtIndex:0];
        NSString *dataString = [arguments objectAtIndex:1];
        NSInteger timeToLive = [[arguments objectAtIndex:2] integerValue];
        NSString *uploaderPublicIP = [arguments objectAtIndex:3];
        NSString *uploaderPrivateIP = [arguments objectAtIndex:4];
        timeToLive -= 1;
        NSData *data = [dataString dataUsingEncoding:NSUTF8StringEncoding];
        NSString *messageString = [RSMessenger messageWithIdentifier:@"UP_REQ" arguments:@[fileName,[RSUtilities publicIpAddress],[RSUtilities privateIpAddress],[NSString stringWithFormat:@"%ld",(unsigned long)timeToLive]]];
        //Prevent error
        if ([RSUtilities freeDiskspace] < data.length) {
            messageString = [RSMessenger messageWithIdentifier:@"UP_REQ" arguments:@[fileName,uploaderPublicIP,uploaderPrivateIP,[NSString stringWithFormat:@"%d",timeToLive + 1]]];
        }
        else
        {
            [data writeToFile:[NSString stringWithFormat:@"%@%@",STORED_DATA_DIRECTORY,fileName] atomically:YES];
        }
        if (timeToLive > 0) {
            NSArray *contactPublicIpList = [RSUtilities contactPublicIpListWithKValue:K_UPLOAD];
            NSArray *contactPrivateIpList = [RSUtilities contactPrivateIpListWithKValue:K_UPLOAD];
            for (NSInteger i = 0; i < K_UPLOAD; i++) {
                if (i < contactPublicIpList.count && ![[contactPublicIpList objectAtIndex:i] isEqualToString:uploaderPublicIP] && ![[contactPrivateIpList objectAtIndex:i] isEqualToString:uploaderPrivateIP]) {
                    NSString *contactPublicIP = [contactPublicIpList objectAtIndex:i];
                    NSString *contactPrivateIP = [contactPrivateIpList objectAtIndex:i];
                    RSMessenger *message = [RSMessenger messengerWithPort:MESSAGE_PORT delegate:self];
                    [message sendUdpMessage:messageString toHostWithPublicAddress:contactPublicIP privateAddress:contactPrivateIP tag:0];
                }
            }
        }
    }
}

- (void)messenger:(RSMessenger *)messenger didNotSendMessage:(NSString *)message toPublicAddress:(NSString *)publicAddress privateAddress:(NSString *)privateAddress tag:(NSInteger)tag error:(NSError *)error
{
    if ([[RSMessenger identifierOfMessage:message] isEqualToString:@"UP_REQ"] || [[RSMessenger identifierOfMessage:message] isEqualToString:@"U_FILE_DATA"]) {
        NSString *fileName = [[RSMessenger argumentsOfMessage:message] objectAtIndex:0];
        for (id delegate in delegates) {
            if ([delegate respondsToSelector:@selector(uploadDidFail)]) {
                [delegate uploadDidFail:fileName];
            }
        }
    }
}

@end
