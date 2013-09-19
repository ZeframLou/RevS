//
//  RSUpload.m
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
    }
    return sharedInstance;
}

+ (void)uploadFile:(NSString *)fileName
{
    NSArray *contactList = [RSUtilities onlineNeighbors];
    
    for (NSInteger i = 0; i < K_UPLOAD; i++) {
        if (i < contactList.count) {
            NSString *publicAddress = [contactList objectAtIndex:i];
            NSString *messageString = [RSMessenger messageWithIdentifier:@"UP_REQ" arguments:@[fileName,[RSUtilities publicIpAddress],[NSString stringWithFormat:@"%ld",(unsigned long)TTL]]];
            RSMessenger *message = [RSMessenger messengerWithPort:MESSAGE_PORT];
            [message addDelegate:[RSUpload sharedInstance]];
            [message sendUdpMessage:messageString toHost:publicAddress tag:UPLOAD_TAG];
        }
    }
}

+ (void)uploadFile:(NSString *)fileName toAddress:(NSString *)publicAddress
{
    NSString *messageString = [RSMessenger messageWithIdentifier:@"U_FILE_DATA" arguments:@[fileName,[NSData decryptData:[NSData dataWithContentsOfFile:[STORED_DATA_DIRECTORY stringByAppendingString:fileName]] withKey:FILE_CODE],@"0",[RSUtilities publicIpAddress]]];
    RSMessenger *message = [RSMessenger messengerWithPort:MESSAGE_PORT];
    [message addDelegate:[RSUpload sharedInstance]];
    [message sendUdpMessage:messageString toHost:publicAddress tag:UPLOAD_TAG];
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
        NSInteger timeToLive = [[arguments objectAtIndex:2] integerValue];
        RSMessenger *message = [RSMessenger messengerWithPort:MESSAGE_PORT];
        [message addDelegate:self];
        [message sendUdpMessage:[RSMessenger messageWithIdentifier:@"UP_READY" arguments:@[fileName,[RSUtilities publicIpAddress],[NSString stringWithFormat:@"%ld",(unsigned long)timeToLive]]] toHost:fileOwnerPublicIP  tag:UPLOAD_TAG];
    }
    else if ([identifier isEqualToString:@"UP_READY"])
    {
        NSString *fileName = [arguments objectAtIndex:0];
        NSString *requesterPublicIP = [arguments objectAtIndex:1];
        NSInteger timeToLive = [[arguments objectAtIndex:2] integerValue];
        NSData *data = [NSData dataWithContentsOfFile:[NSString stringWithFormat:@"%@%@",STORED_DATA_DIRECTORY,fileName]];
        NSString *dataString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSString *string = [RSMessenger messageWithIdentifier:@"U_FILE_DATA" arguments:@[fileName,dataString,[NSString stringWithFormat:@"%ld",(unsigned long)timeToLive],requesterPublicIP]];
        RSMessenger *message = [RSMessenger messengerWithPort:MESSAGE_PORT];
        [message addDelegate:self];
        [message sendUdpMessage:string toHost:requesterPublicIP tag:UPLOAD_TAG];
        for (id delegate in delegates) {
            if ([delegate respondsToSelector:@selector(didUploadFile:)]) {
                [delegate didUploadFile:fileName];
            }
        }
    }
    else if ([identifier isEqualToString:@"U_FILE_DATA"]) {
        NSString *fileName = [arguments objectAtIndex:0];
        NSString *dataString = [arguments objectAtIndex:1];
        NSInteger timeToLive = [[arguments objectAtIndex:2] integerValue];
        NSString *uploaderPublicIP = [arguments objectAtIndex:3];
        timeToLive -= 1;
        NSData *data = [dataString dataUsingEncoding:NSUTF8StringEncoding];
        NSString *string = [RSMessenger messageWithIdentifier:@"UP_REQ" arguments:@[fileName,[RSUtilities publicIpAddress],[NSString stringWithFormat:@"%ld",(unsigned long)timeToLive]]];
        //Prevent error
        if ([RSUtilities freeDiskspace] < data.length) {
            string = [RSMessenger messageWithIdentifier:@"UP_REQ" arguments:@[fileName,uploaderPublicIP,[NSString stringWithFormat:@"%ld",timeToLive + 1]]];
        }
        else
        {
            [data writeToFile:[NSString stringWithFormat:@"%@%@",STORED_DATA_DIRECTORY,fileName] atomically:YES];
        }
        if (timeToLive > 0) {
            NSArray *contactList = [RSUtilities contactListWithKValue:K_NEIGHBOR];
            for (NSInteger i = 0; i < K_UPLOAD; i++) {
                if (i < contactList.count && ![[contactList objectAtIndex:i] isEqualToString:uploaderPublicIP]) {
                    NSString *contactPublicIP = [contactList objectAtIndex:i];
                    RSMessenger *message = [RSMessenger messengerWithPort:MESSAGE_PORT];
                    [message addDelegate:self];
                    [message sendUdpMessage:string toHost:contactPublicIP tag:UPLOAD_TAG];
                }
            }
        }
        
        for (id delegate in delegates) {
            if ([delegate respondsToSelector:@selector(didUploadFile:)]) {
                [delegate didUploadFile:fileName];
            }
        }
    }
}

- (void)messenger:(RSMessenger *)messenger didNotSendDataWithTag:(NSInteger)tag error:(NSError *)error
{
    for (id delegate in delegates) {
        if ([delegate respondsToSelector:@selector(uploadDidFail)]) {
            [delegate uploadDidFail];
        }
    }
}

@end
