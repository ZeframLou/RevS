//
//  RSDownload.m
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
        [RSMessenger registerMessageIdentifiers:@[@"DOWN_REQ",@"INC_P_INDEX",@"HAS_FILE",@"DOWN_FILE",@"D_FILE_DATA"] delegate:sharedInstance];
    }
    return sharedInstance;
}

+ (void)downloadFile:(NSString *)fileName
{
    NSArray *contactPublicIpList = [RSUtilities contactPublicIpListWithKValue:K];
    NSArray *contactPrivateIpList = [RSUtilities contactPrivateIpListWithKValue:K];
    [[NSUserDefaults standardUserDefaults]removeObjectForKey:[NSString stringWithFormat:@"%@:gotAHit",fileName]];
    //Send search query
    NSInteger i = 0;
    for (NSString *string in contactPublicIpList) {
        NSString *publicIP = string;
        NSString *privateIP = [contactPrivateIpList objectAtIndex:i];
        NSString *messageString = [RSMessenger messageWithIdentifier:@"DOWN_REQ" arguments:@[[RSUtilities publicIpAddress],[RSUtilities privateIpAddress],[RSUtilities publicIpAddress],[RSUtilities privateIpAddress],fileName,[NSString stringWithFormat:@"%ld",(unsigned long)TTL]]];
        RSMessenger *messenger = [RSMessenger messengerWithPort:MESSAGE_PORT delegate:[RSDownload sharedInstance]];
        [messenger sendUdpMessage:messageString toHostWithPublicAddress:publicIP privateAddress:privateIP tag:0];
        i++;
    }
}

+ (void)downloadFile:(NSString *)fileName fromPublicAddress:(NSString *)publicAddress privateAddress:(NSString *)privateAddress
{
    RSMessenger *messenger = [RSMessenger messengerWithPort:MESSAGE_PORT delegate:[RSDownload sharedInstance]];
    [messenger sendUdpMessage:[RSMessenger messageWithIdentifier:@"DOWN_FILE" arguments:@[fileName,[RSUtilities publicIpAddress],[RSUtilities privateIpAddress]]] toHostWithPublicAddress:publicAddress privateAddress:privateAddress tag:0];
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
        //Address of the requester of this download query
        NSString *requesterPublicIP = [arguments objectAtIndex:0];
        NSString *requesterPrivateIP = [arguments objectAtIndex:1];
        //Address of the sender of this message
        NSString *senderPublicIP = [arguments objectAtIndex:2];
        NSString *senderPrivateIP = [arguments objectAtIndex:3];
        NSString *fileName = [arguments objectAtIndex:4];
        NSInteger ttl = [[arguments objectAtIndex:5] integerValue];
        ttl -= 1;
        if (ttl > 0) {
            if ([[RSUtilities listOfFilenames]containsObject:fileName]) {
                //Ooh,you have the file!First,send a message to the sender to increase the probability index on this path
                NSInteger prevNodeCount = TTL - ttl;
                NSInteger decAmount = INDEX_INC / prevNodeCount;
                NSString *incIndexMessageString = [RSMessenger messageWithIdentifier:@"INC_P_INDEX" arguments:@[[NSString stringWithFormat:@"%ld",(unsigned long)INDEX_INC],[NSString stringWithFormat:@"%ld",(unsigned long)decAmount],[RSUtilities publicIpAddress],[RSUtilities privateIpAddress],fileName]];
                RSMessenger *incIndexMessage = [RSMessenger messengerWithPort:MESSAGE_PORT delegate:self];
                [incIndexMessage sendUdpMessage:incIndexMessageString toHostWithPublicAddress:senderPublicIP privateAddress:senderPrivateIP tag:0];
                
                //Next,tell the requester that you have the file
                NSString *string = [RSMessenger messageWithIdentifier:@"HAS_FILE" arguments:@[fileName,[RSUtilities publicIpAddress],[RSUtilities privateIpAddress]]];
                RSMessenger *message = [RSMessenger messengerWithPort:MESSAGE_PORT delegate:self];
                [message sendUdpMessage:string toHostWithPublicAddress:requesterPublicIP privateAddress:requesterPrivateIP tag:0];
            }
            else {
                //You don't have the file,so pass on the query to the neighbors
                [[NSUserDefaults standardUserDefaults]setObject:[NSString stringWithFormat:@"%@,%@",senderPublicIP,senderPublicIP] forKey:[NSString stringWithFormat:@"%@:sender",[RSUtilities hashFromString:fileName]]];
                NSArray *contactPublicIpList = [RSUtilities contactPublicIpListWithKValue:K_NEIGHBOR];
                NSArray *contactPrivateIpList = [RSUtilities contactPrivateIpListWithKValue:K_NEIGHBOR];
                NSInteger i = 0;
                for (NSString *string in contactPublicIpList) {
                    NSString *publicIP = string;
                    NSString *privateIP = [contactPrivateIpList objectAtIndex:i];
                    if (![requesterPublicIP isEqualToString:publicIP]) {
                        NSString *messageString = [RSMessenger messageWithIdentifier:@"DOWN_REQ" arguments:@[requesterPublicIP,requesterPrivateIP,[RSUtilities publicIpAddress],[RSUtilities privateIpAddress],fileName,[NSString stringWithFormat:@"%ld",(unsigned long)ttl]]];
                        RSMessenger *message = [RSMessenger messengerWithPort:MESSAGE_PORT delegate:self];
                        [message sendUdpMessage:messageString toHostWithPublicAddress:publicIP privateAddress:privateIP tag:0];
                    }
                    i++;
                }
            }
        }
    }
    else if ([identifier isEqualToString:@"INC_P_INDEX"]) {
        NSInteger inc = [[arguments objectAtIndex:0] integerValue];
        NSInteger dec = [[arguments objectAtIndex:1] integerValue];
        NSString *senderPublicIP = [arguments objectAtIndex:2];
        NSString *senderPrivateIP = [arguments objectAtIndex:3];
        NSString *fileName = [arguments objectAtIndex:4];
        
        NSString *ipString = [NSString stringWithFormat:@"%@,%@",senderPublicIP,senderPrivateIP];
        
        //Change probability index
        NSString *dataString = [NSData decryptData:[NSData dataWithContentsOfFile:PROB_INDEX_PATH] withKey:FILE_CODE];
        NSMutableArray *dataArray;
        if (dataString.length == 0) {
            dataArray = [NSMutableArray array];
        }
        else
        {
            dataArray = [NSMutableArray arrayWithArray:[dataString componentsSeparatedByString:@";"]];
        }
        NSMutableArray *probIndexList = [NSMutableArray array];
        NSMutableArray *probIndexContactList = [NSMutableArray array];
        for (NSString *string in dataArray) {
            NSArray *array = [string componentsSeparatedByString:@":"];
            NSString *ipAddress = [array objectAtIndex:0];
            NSNumber *probIndex = [NSNumber numberWithInteger:[[array lastObject]integerValue]];
            [probIndexContactList addObject:ipAddress];
            [probIndexList addObject:probIndex];
        }
        NSInteger senderProbIndex = [[probIndexList objectAtIndex:[probIndexContactList indexOfObject:ipString]] integerValue];
        if (inc <= 0) {
            inc = 1;
        }
        senderProbIndex += inc;
        [dataArray replaceObjectAtIndex:[probIndexContactList indexOfObject:ipString] withObject:[NSString stringWithFormat:@"%@:%ld",ipString,(unsigned long)senderProbIndex]];
        NSString *newProbIndexString = [dataArray componentsJoinedByString:@";"];
        [[NSData encryptString:newProbIndexString withKey:FILE_CODE]writeToFile:PROB_INDEX_PATH atomically:YES];
        
        //Pass on the message
        NSString *senderKey = [NSString stringWithFormat:@"%@:sender",[RSUtilities hashFromString:fileName]];
        NSString *string = [[NSUserDefaults standardUserDefaults]objectForKey:senderKey];
        [[NSUserDefaults standardUserDefaults]removeObjectForKey:senderKey];
        if (string) {
            NSString *publicIP = [[string componentsSeparatedByString:@","]objectAtIndex:0];
            NSString *privateIP = [[string componentsSeparatedByString:@","]objectAtIndex:1];
            NSString *incIndexMessageString = [RSMessenger messageWithIdentifier:@"INC_P_INDEX" arguments:@[[NSString stringWithFormat:@"%ld",(unsigned long)inc - dec],[NSString stringWithFormat:@"%ld",(unsigned long)dec],[RSUtilities publicIpAddress],[RSUtilities privateIpAddress],fileName]];
            RSMessenger *incIndexMessage = [RSMessenger messengerWithPort:MESSAGE_PORT delegate:self];
            [incIndexMessage sendUdpMessage:incIndexMessageString toHostWithPublicAddress:publicIP privateAddress:privateIP tag:0];
        }
    }
    else if ([identifier isEqualToString:@"HAS_FILE"])
    {
        NSString *fileName = [arguments objectAtIndex:0];
        if (![[NSUserDefaults standardUserDefaults]boolForKey:[NSString stringWithFormat:@"%@:gotAHit",fileName]]) {
            NSString *fileOwnerPublicIP = [arguments objectAtIndex:1];
            NSString *fileOwnerPrivateIP = [arguments objectAtIndex:2];
            [[NSUserDefaults standardUserDefaults]setBool:YES forKey:[NSString stringWithFormat:@"%@:gotAHit",fileName]];
            RSMessenger *message = [RSMessenger messengerWithPort:MESSAGE_PORT delegate:self];
            [message sendUdpMessage:[RSMessenger messageWithIdentifier:@"DOWN_FILE" arguments:@[fileName,[RSUtilities publicIpAddress],[RSUtilities privateIpAddress]]] toHostWithPublicAddress:fileOwnerPublicIP privateAddress:fileOwnerPrivateIP tag:0];
        }
    }
    else if ([identifier isEqualToString:@"DOWN_FILE"])
    {
        NSString *fileName = [arguments objectAtIndex:0];
        NSString *requesterPublicIP = [arguments objectAtIndex:1];
        NSString *requesterPrivateIP = [arguments objectAtIndex:2];
        NSData *data = [NSData dataWithContentsOfFile:[NSString stringWithFormat:@"%@%@",STORED_DATA_DIRECTORY,fileName]];
        NSString *dataString = [NSData decryptData:data withKey:FILE_CODE];
        NSString *string = [RSMessenger messageWithIdentifier:@"D_FILE_DATA" arguments:@[fileName,[RSUtilities publicIpAddress],[RSUtilities privateIpAddress],dataString]];
        RSMessenger *message = [RSMessenger messengerWithPort:MESSAGE_PORT delegate:self];
        [message sendUdpMessage:string toHostWithPublicAddress:requesterPublicIP privateAddress:requesterPrivateIP tag:0];
    }
    else if ([identifier isEqualToString:@"D_FILE_DATA"]) {
        NSString *fileName = [arguments objectAtIndex:0];
        NSString *publicIp = [arguments objectAtIndex:1];
        NSString *privateIp = [arguments objectAtIndex:2];
        NSString *dataString = [arguments objectAtIndex:3];
        NSData *data = [NSData encryptString:dataString withKey:FILE_CODE];
        [data writeToFile:[NSString stringWithFormat:@"%@%@",STORED_DATA_DIRECTORY,fileName] atomically:YES];
        for (id delegate in delegates) {
            if ([delegate respondsToSelector:@selector(didDownloadFile:fromPublicAddress:privateAddress:)]) {
                [delegate didDownloadFile:fileName fromPublicAddress:publicIp privateAddress:privateIp];
            }
        }
    }
}

- (void)messenger:(RSMessenger *)messenger didNotSendMessage:(NSString *)message toPublicAddress:(NSString *)publicAddress privateAddress:(NSString *)privateAddress tag:(NSInteger)tag error:(NSError *)error
{
    if ([[RSMessenger identifierOfMessage:message] isEqualToString:@"DOWN_REQ"]) {
        NSString *fileName = [[RSMessenger argumentsOfMessage:message] objectAtIndex:4];
        for (id delegate in delegates) {
            if ([delegate respondsToSelector:@selector(downloadDidFail:)]) {
                [delegate downloadDidFail:fileName];
            }
        }
    }
    else if ([[RSMessenger identifierOfMessage:message] isEqualToString:@"DOWN_FILE"]) {
        NSString *fileName = [[RSMessenger argumentsOfMessage:message] objectAtIndex:0];
        for (id delegate in delegates) {
            if ([delegate respondsToSelector:@selector(downloadDidFail:)]) {
                [delegate downloadDidFail:fileName];
            }
        }
    }
}

@end
