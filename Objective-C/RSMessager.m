//
//  RSMessager.m
//  RevSTest
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

@interface RSMessager () <GCDAsyncSocketDelegate>

@property (nonatomic,strong) NSMutableArray *delegates;
@property (nonatomic) NSInteger tag;
@property (nonatomic) uint16_t port;
@property (nonatomic,strong) NSString *tcpMessage;
@property (nonatomic,strong) GCDAsyncSocket *tcpSocket;

@end

@implementation RSMessager

@synthesize delegates,tag,port,tcpMessage,tcpSocket;

+ (RSMessager *)messagerWithPort:(uint16_t)port
{
    //static RSMessager *messager;
    //if (!messager) {
        RSMessager *messager = [[RSMessager alloc]init];
        messager.delegates = [NSMutableArray array];
        messager.tcpSocket = [[GCDAsyncSocket alloc]initWithDelegate:messager delegateQueue:[RSMessager delegateQueue]];
        [messager.tcpSocket acceptOnPort:port error:nil];
        messager.port = port;
    //}
    return messager;
}

- (void)sendTcpMessage:(NSString *)message toHost:(NSString *)host tag:(NSInteger)tag
{
    self.tag = tag;
    tcpMessage = message;
    if (![[tcpSocket connectedHost] isEqualToString:host] && ![tcpSocket isConnected]) {
        [tcpSocket disconnect];
        NSError *error;
        [tcpSocket connectToHost:host onPort:port error:&error];
        if (error) {
            NSLog(@"%@",error);
        }
    }
    else
    {
        [tcpSocket writeData:[NSData encryptString:tcpMessage withKey:CODE] withTimeout:30 tag:tag];
    }
}

- (void)addDelegate:(id <RSMessagerDelegate>)delegate
{
    if (![delegates containsObject:delegate]) {
        [delegates addObject:delegate];
    }
}

+ (dispatch_queue_t)delegateQueue
{
    static dispatch_queue_t queue;
    if (!queue) {
        queue = dispatch_queue_create("delegate queue", NULL);
    }
    return queue;
}

+ (dispatch_queue_t)filterQueue
{
    static dispatch_queue_t queue;
    if (!queue) {
        queue = dispatch_queue_create("filter queue", NULL);
    }
    return queue;
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port
{
    [sock writeData:[NSData encryptString:tcpMessage withKey:CODE] withTimeout:30 tag:tag];
}

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
    tcpSocket.delegate = self;
    tcpSocket.delegateQueue = [RSMessager delegateQueue];
    NSError *error;
    if (error) {
        NSLog(@"%@",error);
    }
    [tcpSocket readDataWithTimeout:-1 tag:0];
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    dispatch_async(dispatch_get_main_queue(), ^{
        for (id delegate in delegates) {
            if ([delegate respondsToSelector:@selector(messager:didRecieveData:tag:)]) {
                [delegate messager:self didRecieveData:data tag:tag];
            }
        }
    });
    [tcpSocket readDataWithTimeout:-1 tag:0];
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    dispatch_async(dispatch_get_main_queue(), ^{
        for (id delegate in delegates) {
            if ([delegate respondsToSelector:@selector(messager:didWriteDataWithTag:)]) {
                [delegate messager:self didWriteDataWithTag:tag];
            }
        }
    });
    [tcpSocket readDataWithTimeout:-1 tag:0];
}

@end
