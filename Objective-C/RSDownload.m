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

@interface RSDownload () <RSListenerDelegate>

@property (nonatomic,strong) NSMutableArray *delegates;
@property (nonatomic,strong) RSMessager *messager;

@end

@implementation RSDownload

@synthesize delegates,messager;

+ (RSDownload *)sharedInstance
{
    static RSDownload *sharedInstance;
    if (!sharedInstance) {
        sharedInstance = [[RSDownload alloc]init];
        sharedInstance.delegates = [NSMutableArray array];
        sharedInstance.messager = [RSMessager messagerWithPort:DOWNLOAD_PORT];
        [sharedInstance.messager addDelegate:[RSListener sharedListener]];
        [[RSListener sharedListener] addDelegate:sharedInstance];
    }
    return sharedInstance;
}

- (void)downloadFile:(NSString *)fileName;
{
    NSArray *contactList = [RSUtilities contactListWithKValue:K];
    //Send search query
    for (NSString *ipAddress in contactList) {
        NSString *messageString = [NSString stringWithFormat:@"S_%@;%@;%@;%ld",[RSUtilities getLocalIPAddress],[RSUtilities getLocalIPAddress],fileName,(unsigned long)TTL];
        [messager sendTcpMessage:messageString toHost:ipAddress tag:0];
    }
}

- (void)downloadFile:(NSString *)fileName fromIP:(NSString *)ipAddress
{
    [messager sendTcpMessage:[NSString stringWithFormat:@"DFILE_%@,%@",fileName,[RSUtilities getLocalIPAddress]] toHost:ipAddress tag:0];
}

- (void)addDelegate:(id <RSDownloadDelegate>)delegate
{
    if (![delegates containsObject:delegate]) {
        [delegates addObject:delegate];
    }
}

#pragma mark - RSListenerDelegate

- (void)didSaveFile:(NSString *)fileName
{
    for (id delegate in delegates) {
        if ([delegate respondsToSelector:@selector(didDownloadFile:)]) {
            [delegate didDownloadFile:fileName];
        }
    }
}

@end
