//
//  RSDownload.m
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

@interface RSDownload () <RSMessengerDelegate>

@property (nonatomic,strong) NSMutableArray *delegates;

@end

@implementation RSDownload

@synthesize delegates;

+ (RSDownload *)sharedInstance
{
    static RSDownload *sharedInstance;
    if (!sharedInstance) {
        sharedInstance = [[RSDownload alloc]init];
        sharedInstance.delegates = [NSMutableArray array];
    }
    return sharedInstance;
}

+ (void)downloadFile:(NSString *)fileName;
{
    NSArray *contactList = [RSUtilities contactListWithKValue:K];
    [[NSUserDefaults standardUserDefaults]removeObjectForKey:[NSString stringWithFormat:@"%@:gotAHit",fileName]];
    //Send search query
    for (NSString *string in contactList) {
        NSString *publicIP = string;
        NSString *messageString = [RSMessenger messageWithIdentifier:@"DOWN_REQ" arguments:@[[RSUtilities publicIpAddress],[RSUtilities publicIpAddress],fileName,[NSString stringWithFormat:@"%ld",(unsigned long)TTL]]];
        RSMessenger *messenger = [RSMessenger messengerWithPort:MESSAGE_PORT];
        [messenger addDelegate:[RSDownload sharedInstance]];
        [messenger sendUdpMessage:messageString toHost:publicIP tag:DOWNLOAD_TAG];
    }
}

+ (void)downloadFile:(NSString *)fileName fromAddress:(NSString *)publicAddress;
{
    RSMessenger *messenger = [RSMessenger messengerWithPort:MESSAGE_PORT];
    [messenger addDelegate:[RSDownload sharedInstance]];
    [messenger sendUdpMessage:[RSMessenger messageWithIdentifier:@"DOWN_FILE" arguments:@[fileName,[RSUtilities publicIpAddress]]] toHost:publicAddress tag:DOWNLOAD_TAG];
}

+ (void)addDelegate:(id <RSDownloadDelegate>)delegate
{
    if (![[RSDownload sharedInstance].delegates containsObject:delegate]) {
        [[RSDownload sharedInstance].delegates addObject:delegate];
    }
}

- (void)messenger:(RSMessenger *)messenger didRecieveMessageWithIdentifier:(NSString *)identifier arguments:(NSArray *)arguments tag:(NSInteger)tag
{
    if ([identifier isEqualToString:@"DOWN_REQ"]) {
        //Someone requested a search
        NSString *requesterPublicIP = [arguments objectAtIndex:0];
        NSString *senderPublicIP = [arguments objectAtIndex:1];
        NSString *fileName = [arguments objectAtIndex:2];
        NSInteger ttl = [[arguments objectAtIndex:3] integerValue];
        ttl -= 1;
        if (ttl > 0) {
            if ([[RSUtilities listOfFilenames]containsObject:fileName]) {
                //Ooh,you have the file!First,send a message to the sender to increase the probability index on this path
                NSString *incIndexMessageString = [RSMessenger messageWithIdentifier:@"INC_P_INDEX" arguments:@[[NSString stringWithFormat:@"%ld",(unsigned long)INDEX_INC],[RSUtilities publicIpAddress],fileName]];
                RSMessenger *incIndexMessage = [RSMessenger messengerWithPort:MESSAGE_PORT];
                [incIndexMessage addDelegate:self];
                [incIndexMessage sendUdpMessage:incIndexMessageString toHost:senderPublicIP tag:DOWNLOAD_TAG];
                
                //Next,tell the requester that you have the file
                NSString *string = [RSMessenger messageWithIdentifier:@"HAS_FILE" arguments:@[fileName,[RSUtilities publicIpAddress]]];
                RSMessenger *message = [RSMessenger messengerWithPort:MESSAGE_PORT];
                [message addDelegate:self];
                [message sendUdpMessage:string toHost:requesterPublicIP tag:DOWNLOAD_TAG];
            }
            else {
                //You don't have the file,so send a message to one of the neighbors
                [[NSUserDefaults standardUserDefaults]setObject:senderPublicIP forKey:[NSString stringWithFormat:@"%@:sender",[RSUtilities hashFromString:fileName]]];
                NSArray *contactList = [RSUtilities contactListWithKValue:K_NEIGHBOR];
                for (NSString *string in contactList) {
                    NSString *publicIP = string;
                    if (![requesterPublicIP isEqualToString:publicIP]) {
                        NSString *messageString = [RSMessenger messageWithIdentifier:@"DOWN_REQ" arguments:@[requesterPublicIP,[RSUtilities publicIpAddress],fileName,[NSString stringWithFormat:@"%ld",(unsigned long)ttl]]];
                        RSMessenger *message = [RSMessenger messengerWithPort:MESSAGE_PORT];
                        [message addDelegate:self];
                        [message sendUdpMessage:messageString toHost:publicIP tag:DOWNLOAD_TAG];
                    }
                }
            }
        }
    }
    else if ([identifier isEqualToString:@"INC_P_INDEX"]) {
        NSInteger inc = [[arguments objectAtIndex:0] integerValue];
        NSString *senderPublicIP = [arguments objectAtIndex:1];
        NSString *fileName = [arguments objectAtIndex:2];
        
        //Change probability index
        NSString *dataString = [NSData decryptData:[NSData dataWithContentsOfFile:PROB_INDEX_PATH] withKey:FILE_CODE];
        NSMutableArray *dataArray = [NSMutableArray arrayWithArray:[dataString componentsSeparatedByString:@"/"]];
        
        NSMutableArray *probIndexList = [NSMutableArray array];
        NSMutableArray *probIndexContactList = [NSMutableArray array];
        for (NSString *string in dataArray) {
            NSArray *array = [string componentsSeparatedByString:@":"];
            NSString *ipAddress = [array objectAtIndex:0];
            NSNumber *probIndex = [NSNumber numberWithInteger:[[array lastObject]integerValue]];
            [probIndexContactList addObject:ipAddress];
            [probIndexList addObject:probIndex];
        }
        NSInteger senderProbIndex = [[probIndexList objectAtIndex:[probIndexContactList indexOfObject:senderPublicIP]] integerValue];
        senderProbIndex += inc;
        [dataArray replaceObjectAtIndex:[probIndexContactList indexOfObject:senderPublicIP] withObject:[NSString stringWithFormat:@"%@:%ld",senderPublicIP,(unsigned long)senderProbIndex]];
        NSString *newProbIndexString = [dataArray componentsJoinedByString:@"/"];
        [[NSData encryptString:newProbIndexString withKey:FILE_CODE]writeToFile:PROB_INDEX_PATH atomically:YES];
        
        //Pass on the message
        NSString *senderKey = [NSString stringWithFormat:@"%@:sender",[RSUtilities hashFromString:fileName]];
        NSString *string = [[NSUserDefaults standardUserDefaults]objectForKey:senderKey];
        [[NSUserDefaults standardUserDefaults]removeObjectForKey:senderKey];
        if (string) {
            NSString *publicIP = string;
            NSString *incIndexMessageString = [RSMessenger messageWithIdentifier:@"INC_P_INDEX" arguments:@[[NSString stringWithFormat:@"%ld",(unsigned long)INDEX_INC],[RSUtilities publicIpAddress],fileName]];
            RSMessenger *incIndexMessage = [RSMessenger messengerWithPort:MESSAGE_PORT];
            [incIndexMessage addDelegate:self];
            [incIndexMessage sendUdpMessage:incIndexMessageString toHost:publicIP tag:DOWNLOAD_TAG];
        }
    }
    else if ([identifier isEqualToString:@"HAS_FILE"])
    {
        NSString *fileName = [arguments objectAtIndex:0];
        if (![[NSUserDefaults standardUserDefaults]boolForKey:[NSString stringWithFormat:@"%@:gotAHit",fileName]]) {
            NSString *fileOwnerPublicIP = [arguments objectAtIndex:1];
            [[NSUserDefaults standardUserDefaults]setBool:YES forKey:[NSString stringWithFormat:@"%@:gotAHit",fileName]];
            RSMessenger *message = [RSMessenger messengerWithPort:MESSAGE_PORT];
            [message addDelegate:self];
            [message sendUdpMessage:[RSMessenger messageWithIdentifier:@"DOWN_FILE" arguments:@[fileName,[RSUtilities publicIpAddress]]] toHost:fileOwnerPublicIP tag:DOWNLOAD_TAG];
        }
    }
    else if ([identifier isEqualToString:@"DOWN_FILE"])
    {
        NSString *fileName = [arguments objectAtIndex:0];
        NSString *requesterPublicIP = [arguments objectAtIndex:1];
        NSData *data = [NSData dataWithContentsOfFile:[NSString stringWithFormat:@"%@%@",STORED_DATA_DIRECTORY,fileName]];
        NSString *dataString = [NSData decryptData:data withKey:FILE_CODE];//[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSString *string = [RSMessenger messageWithIdentifier:@"FILE_DATA" arguments:@[fileName,dataString]];
        RSMessenger *message = [RSMessenger messengerWithPort:MESSAGE_PORT];
        [message addDelegate:self];
        [message sendUdpMessage:string toHost:requesterPublicIP tag:DOWNLOAD_TAG];
    }
    else if ([identifier isEqualToString:@"D_FILE_DATA"]) {
        NSString *fileName = [arguments objectAtIndex:0];
        NSString *dataString = [arguments objectAtIndex:1];
        NSData *data = [NSData encryptString:dataString withKey:FILE_CODE];
        [data writeToFile:[NSString stringWithFormat:@"%@%@",STORED_DATA_DIRECTORY,fileName] atomically:YES];
        for (id delegate in delegates) {
            if ([delegate respondsToSelector:@selector(didDownloadFile:)]) {
                [delegate didDownloadFile:fileName];
            }
        }
    }
}

- (void)messenger:(RSMessenger *)messenger didNotSendDataWithTag:(NSInteger)tag error:(NSError *)error
{
    for (id delegate in delegates) {
        if ([delegate respondsToSelector:@selector(downloadDidFail)]) {
            [delegate downloadDidFail];
        }
    }
}

@end
