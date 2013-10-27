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

static NSMutableArray *connectedAddresses;
static RSNatTier natTier;

@interface RSUtilities ()

@end

@implementation RSUtilities

+ (NSArray *)localPublicIpList
{
    NSData *data = [NSData dataWithContentsOfFile:IP_LIST_PATH];
    NSString *string = [NSData decryptData:data withKey:FILE_CODE];
    NSMutableArray *ipArray = [NSMutableArray array];
    NSArray *dataArray;
    if (string.length > 0) {
        dataArray = [string componentsSeparatedByString:@";"];
        for (NSString *dataString in dataArray) {
            NSArray *array = [dataString componentsSeparatedByString:@"|"];
            NSString *ipAddressString = [array objectAtIndex:1];
            [ipArray addObject:[[ipAddressString componentsSeparatedByString:@","] objectAtIndex:0]];
        }
    }
    return ipArray;
}

+ (NSArray *)localPrivateIpList
{
    NSData *data = [NSData dataWithContentsOfFile:IP_LIST_PATH];
    NSString *string = [NSData decryptData:data withKey:FILE_CODE];
    NSMutableArray *ipArray = [NSMutableArray array];
    NSArray *dataArray;
    if (string.length > 0) {
        dataArray = [string componentsSeparatedByString:@";"];
        for (NSString *dataString in dataArray) {
            NSArray *array = [dataString componentsSeparatedByString:@"|"];
            NSString *ipAddressString = [array objectAtIndex:1];
            [ipArray addObject:[[ipAddressString componentsSeparatedByString:@","] objectAtIndex:1]];
        }
    }
    return ipArray;
}

+ (NSArray *)onlineNeighborsPublicIpList
{
    NSData *data = [NSData dataWithContentsOfFile:IP_LIST_PATH];
    NSString *string = [NSData decryptData:data withKey:FILE_CODE];
    NSMutableArray *neighborArray = [NSMutableArray array];
    NSArray *dataArray;
    if (string.length > 0) {
        dataArray = [string componentsSeparatedByString:@";"];
        for (NSString *dataString in dataArray) {
            NSArray *array = [dataString componentsSeparatedByString:@"|"];
            NSString *ipAddressString = [[[array objectAtIndex:1] componentsSeparatedByString:@","] objectAtIndex:0];
            BOOL isOnline = [[array objectAtIndex:2] integerValue];
            if (isOnline) {
                [neighborArray addObject:ipAddressString];
            }
        }
    }
    return neighborArray;
}

+ (NSArray *)onlineNeighborsPrivateIpList
{
    NSData *data = [NSData dataWithContentsOfFile:IP_LIST_PATH];
    NSString *string = [NSData decryptData:data withKey:FILE_CODE];
    NSMutableArray *neighborArray = [NSMutableArray array];
    NSArray *dataArray;
    if (string.length > 0) {
        dataArray = [string componentsSeparatedByString:@";"];
        for (NSString *dataString in dataArray) {
            NSArray *array = [dataString componentsSeparatedByString:@"|"];
            NSString *ipAddressString = [[[array objectAtIndex:1] componentsSeparatedByString:@","] objectAtIndex:1];
            BOOL isOnline = [[array objectAtIndex:2] integerValue];
            if (isOnline) {
                [neighborArray addObject:ipAddressString];
            }
        }
    }
    return neighborArray;
}

+ (NSArray *)contactPublicIpListWithKValue:(NSInteger)k
{
    NSArray *ipList = [RSUtilities onlineNeighborsPublicIpList];
    
    if (k > ipList.count) {
        k = ipList.count;
    }
    //Get the online neighbors and the coresponding probability index value
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
        if ([ipList containsObject:ipAddress]) {
            NSNumber *probIndex = [NSNumber numberWithInteger:[[array lastObject]integerValue]];
            [probIndexContactList addObject:ipAddress];
            [probIndexList addObject:probIndex];
        }
    }
    //Get the neighbors with the highest probability value
    NSMutableArray *contactList = [NSMutableArray array];
    NSArray *sortedIndexList = [probIndexList sortedArrayUsingSelector:@selector(compare:)];
    //sortedIndexList is the sorted version of probIndexList in an ascending order.
    NSArray *indexList = [sortedIndexList subarrayWithRange:NSMakeRange(sortedIndexList.count - k, k)];
    for (NSInteger i = 0; i < dataArray.count; i++) {
        if (contactList.count == k) {
            break;
        }
        if ([indexList containsObject:[probIndexList objectAtIndex:i]]) {
            [contactList addObject:[probIndexContactList objectAtIndex:i]];
        }
    }
    
    return contactList;
}

+ (NSArray *)contactPrivateIpListWithKValue:(NSInteger)k
{
    NSArray *ipList = [RSUtilities onlineNeighborsPrivateIpList];
    
    if (k > ipList.count) {
        k = ipList.count;
    }
    //Get the online neighbors and the coresponding probability index value
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
        if ([ipList containsObject:ipAddress]) {
            NSNumber *probIndex = [NSNumber numberWithInteger:[[array lastObject]integerValue]];
            [probIndexContactList addObject:ipAddress];
            [probIndexList addObject:probIndex];
        }
    }
    //Get the neighbors with the highest probability value
    NSMutableArray *contactList = [NSMutableArray array];
    NSArray *sortedIndexList = [probIndexList sortedArrayUsingSelector:@selector(compare:)];
    //sortedIndexList is the sorted version of probIndexList in an ascending order.
    NSArray *indexList = [sortedIndexList subarrayWithRange:NSMakeRange(sortedIndexList.count - k, k)];
    for (NSInteger i = 0; i < dataArray.count; i++) {
        if (contactList.count == k) {
            break;
        }
        if ([indexList containsObject:[probIndexList objectAtIndex:i]]) {
            [contactList addObject:[probIndexContactList objectAtIndex:i]];
        }
    }
    
    return contactList;
}

+ (NSString *)privateIpAddress {
    NSString *address;
    if ([RSPortMapper isStarted]) {
        address = [RSPortMapper privateAddress];
    }
    else {
        address = @"error";
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
        freeifaddrs(interfaces);
    }
    
    return address;
}

+ (NSString *)publicIpAddress {
    NSString *address;
    if ([RSPortMapper isStarted]) {
        address = [RSPortMapper publicAddress];
    }
    else {
        NSString *string = [NSString stringWithContentsOfURL:[NSURL URLWithString:@"http://www.checkip.org"] encoding:NSUTF8StringEncoding error:nil];
        address = [string substringWithRange:NSMakeRange([string rangeOfString:@"<span style=\"color: #5d9bD3;\">"].location + 30, [string rangeOfString:@"</span></h1>"].location - ([string rangeOfString:@"<span style=\"color: #5d9bD3;\">"].location + 30))];
    }
    return address;
}

+ (NSString *)hashFromString:(NSString *)string
{
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    uint8_t digest[CC_SHA1_DIGEST_LENGTH];
    
    CC_SHA1(data.bytes, data.length, digest);
    
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    
    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++)
    {
        [output appendFormat:@"%02x", digest[i]];
    }
    return output;
}

+ (NSArray *)listOfFilenames
{
    NSArray *fileList = [[NSFileManager defaultManager]contentsOfDirectoryAtPath:STORED_DATA_DIRECTORY error:nil];
    return fileList;
}

+ (uint64_t)freeDiskspace
{
    uint64_t totalSpace = 0;
    uint64_t totalFreeSpace = 0;
    
    __autoreleasing NSError *error = nil;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSDictionary *dictionary = [[NSFileManager defaultManager] attributesOfFileSystemForPath:[paths lastObject] error: &error];
    
    if (dictionary) {
        NSNumber *fileSystemSizeInBytes = [dictionary objectForKey: NSFileSystemSize];
        NSNumber *freeFileSystemSizeInBytes = [dictionary objectForKey:NSFileSystemFreeSize];
        totalSpace = [fileSystemSizeInBytes unsignedLongLongValue];
        totalFreeSpace = [freeFileSystemSizeInBytes unsignedLongLongValue];
    } else {
        NSLog(@"Error Obtaining System Memory Info: Domain = %@, Code = %ld", [error domain], (long)[error code]);
    }
    
    return totalFreeSpace;
}

+ (NSString *)deviceID
{
    return [[NSUserDefaults standardUserDefaults]objectForKey:@"deviceID"];
}

+ (BOOL)ipHasChanged
{
    return ![[[NSUserDefaults standardUserDefaults]objectForKey:@"lastIPHash"] isEqualToString:[RSUtilities hashFromString:[NSString stringWithFormat:@"%@,%@",[RSUtilities publicIpAddress],[RSUtilities privateIpAddress]]]];
}

+ (void)updateIPHash
{
    [[NSUserDefaults standardUserDefaults] setObject:[RSUtilities hashFromString:[NSString stringWithFormat:@"%@,%@",[RSUtilities publicIpAddress],[RSUtilities privateIpAddress]]] forKey:@"lastIPHash"];
}

+ (NSArray *)connectedAddresses
{
    if (!connectedAddresses) {
        connectedAddresses = [NSMutableArray array];
    }
    return connectedAddresses;
}

+ (void)addConnectedAddress:(NSString *)address
{
    if (!connectedAddresses) {
        connectedAddresses = [NSMutableArray array];
    }
    if (![connectedAddresses containsObject:address]) {
        [connectedAddresses addObject:address];
    }
}

+ (void)removeConnectedAddress:(NSString *)address;
{
    if (!connectedAddresses) {
        connectedAddresses = [NSMutableArray array];
    }
    [connectedAddresses removeObject:address];
}

+ (RSNatTier)natTier
{
    return natTier;
}

+ (void)setNatTier:(RSNatTier)newTier
{
    natTier = newTier;
}

@end
