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

@interface RSUpload () <RSListenerDelegate>

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
        [RSListener addDelegate:sharedInstance];
    }
    return sharedInstance;
}

+ (void)uploadFile:(NSString *)fileName
{
    NSArray *contactList = [RSUtilities onlineNeighbors];
    
    for (NSUInteger i = 0; i < K_UPLOAD; i++) {
        if (i < contactList.count) {
            NSString *publicAddress = [[[contactList objectAtIndex:i] componentsSeparatedByString:@","] objectAtIndex:0];
            NSString *privateAddress = [[[contactList objectAtIndex:i] componentsSeparatedByString:@","] objectAtIndex:1];
            NSString *messageString = [RSMessenger messageWithIdentifier:@"UFILE" arguments:@[fileName,[RSUtilities publicIpAddress],[RSUtilities privateIPAddress],[NSString stringWithFormat:@"%ld",(unsigned long)TTL]]];
            RSMessenger *message = [RSMessenger messengerWithPort:UPLOAD_PORT];
            [message addDelegate:[RSListener sharedListener]];
            [message sendUdpMessage:messageString toHostWithPublicAddress:publicAddress privateAddress:privateAddress tag:0];
        }
    }
}

+ (void)uploadFile:(NSString *)fileName toPublicAddress:(NSString *)publicAddress privateAddress:(NSString *)privateAddress
{
    NSString *messageString = [RSMessenger messageWithIdentifier:@"SENDFILE" arguments:@[fileName,[NSData decryptData:[NSData dataWithContentsOfFile:[STORED_DATA_DIRECTORY stringByAppendingString:fileName]] withKey:FILE_CODE],@"0",[RSUtilities publicIpAddress],[RSUtilities privateIPAddress]]];
    RSMessenger *message = [RSMessenger messengerWithPort:UPLOAD_PORT];
    [message addDelegate:[RSListener sharedListener]];
    [message sendUdpMessage:messageString toHostWithPublicAddress:publicAddress privateAddress:privateAddress tag:0];
}

+ (void)addDelegate:(id <RSUploadDelegate>)delegate
{
    if (![[RSUpload sharedInstance].delegates containsObject:delegate]) {
        [[RSUpload sharedInstance].delegates addObject:delegate];
    }
}

#pragma mark - RSListenerDelegate

- (void)didUploadFile:(NSString *)fileName
{
    for (id delegate in delegates) {
        if ([delegate respondsToSelector:@selector(didUploadFile:)]) {
            [delegate didUploadFile:fileName];
        }
    }
}

- (void)didRecieveDataWithType:(NSString *)type arguments:(NSArray *)arguments;
{
    
}

@end
