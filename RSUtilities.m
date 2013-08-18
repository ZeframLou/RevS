//
//  RSUtilities.m
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
#import <ifaddrs.h>
#import <arpa/inet.h>

@interface RSUtilities () <RSMessagerDelegate>

@end

@implementation RSUtilities

@synthesize delegate;

+ (NSArray *)localIpList
{
    NSData *data = [NSData dataWithContentsOfFile:IP_LIST_PATH];
    NSString *string = [NSData decryptData:data withKey:CODE];
    NSArray *ipArray;
    if (string.length > 0) {
        ipArray = [string componentsSeparatedByString:@","];
    }
    return ipArray;
}

- (void)remoteIpList
{
    RSMessager *message = [RSMessager messagerWithPort:MESSAGE_PORT];
    [message addDelegate:self];
    [message sendTcpMessage:@"IPLIST" toHost:SERVER_IP tag:0];
}

- (void)remoteIpListInString
{
    RSMessager *message = [RSMessager messagerWithPort:MESSAGE_PORT];
    [message addDelegate:self];
    [message sendTcpMessage:@"IPLIST" toHost:SERVER_IP tag:1];
}

+ (NSArray *)contactListWithKValue:(NSUInteger)k
{
    NSArray *ipList = [RSUtilities localIpList];
    
    //Get the online neighbors and the coresponding probability index value
    NSString *dataString = [NSData decryptData:[NSData dataWithContentsOfFile:PROB_INDEX_PATH] withKey:CODE];
    NSMutableArray *dataArray = [NSMutableArray arrayWithArray:[dataString componentsSeparatedByString:@","]];
    
    NSMutableArray *probIndexList = [NSMutableArray array];
    NSMutableArray *probIndexContactList = [NSMutableArray array];
    for (NSString *string in dataArray) {
        NSArray *array = [string componentsSeparatedByString:@":"];
        NSString *ipAddress = [array objectAtIndex:0];
        if ([ipList containsObject:ipAddress]) {
            NSNumber *probIndex = [NSNumber numberWithInteger:[[array lastObject]integerValue]];
            [probIndexContactList addObject:ipAddress];
            [probIndexList addObject:probIndex];
        }
    }
    //Get the neighbors with the highest probability value
    NSMutableArray *contactList = [NSMutableArray array];
    NSNumber *max = [probIndexList valueForKeyPath:@"@max.intValue"];
    for (NSNumber *number in probIndexList) {
        if ([number isEqualToNumber:max] && contactList.count < k) {
            [contactList addObject:[probIndexContactList objectAtIndex:[probIndexList indexOfObject:number]]];
        }
    }
    
    return contactList;
}

+ (NSString *)getLocalIPAddress {
    /*NSString *address = @"error";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    if (success == 0) {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while(temp_addr != NULL) {
            if(temp_addr->ifa_addr->sa_family == AF_INET) {
                // Check if interface is en0 which is the wifi connection on the iPhone
                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    // Get NSString from C String
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
    }
    // Free memory
    freeifaddrs(interfaces);*/
    NSString *string = [NSString stringWithContentsOfURL:[NSURL URLWithString:@"http://checkip.dyndns.org"] encoding:NSUTF8StringEncoding error:nil];
    NSString *address = [string substringWithRange:NSMakeRange([string rangeOfString:@": "].location + 2, [string rangeOfString:@"</body>"].location - ([string rangeOfString:@": "].location + 2))];
    
    return address;
}

+ (NSString *)hashFromString:(NSString *)string
{
    NSData *data = [string dataUsingEncoding:NSASCIIStringEncoding];
    NSString *hash = [NSString string];
    unsigned char digest[CC_SHA1_DIGEST_LENGTH];
    if (CC_SHA1([data bytes], [data length], digest)) {
        /* SHA-1 hash has been calculated and stored in 'digest'. */
        hash = [NSString stringWithUTF8String:(char *)digest];
    }
    return hash;
}

/*+ (NSArray *)listOfHashedFilenames
{
    NSArray *fileList = [[NSFileManager defaultManager]contentsOfDirectoryAtPath:STORED_DATA_DIRECTORY error:nil];
    NSMutableArray *hashedFileList = [NSMutableArray array];
    for (NSString *fileName in fileList) {
        NSString *hashedFileName = [RSUtilities hashFromString:fileName];
        [hashedFileList addObject:hashedFileName];
    }
    return hashedFileList;
}*/

+ (NSArray *)listOfFilenames
{
    NSArray *fileList = [[NSFileManager defaultManager]contentsOfDirectoryAtPath:STORED_DATA_DIRECTORY error:nil];
    return fileList;
}

#pragma mark - RSMessageDelegate

- (void)messager:(RSMessager *)messager didRecieveData:(NSData *)data tag:(NSInteger)tag;
{
    NSString *messageString = [NSData decryptData:data withKey:CODE];
    NSString *messageType = [[messageString componentsSeparatedByString:@"_"]objectAtIndex:0];
    NSArray *messageArguments = [[[messageString componentsSeparatedByString:@"_"]lastObject]componentsSeparatedByString:@";"];
    if ([messageType isEqualToString:@"IPL"]) {
        NSString *listString = [messageArguments lastObject];
        if (tag == 0) {
            NSArray *ipArray = [listString componentsSeparatedByString:@","];
            [delegate didRecieveRemoteIPList:ipArray];
        }
        else if (tag == 1) {
            [delegate didRecieveRemoteIPList:listString];
        }
    }
}

@end
