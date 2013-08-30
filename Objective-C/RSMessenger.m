//
//  RSMessenger.m
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

@interface RSMessenger () <GCDAsyncSocketDelegate,GCDAsyncUdpSocketDelegate>

@property (nonatomic,strong) NSMutableArray *delegates;
@property (nonatomic) NSInteger tag;
@property (nonatomic) uint16_t port;
@property (nonatomic,strong) NSString *remotePublicAddress;
@property (nonatomic,strong) NSString *remotePrivateAddress;
@property (nonatomic,strong) NSString *connectedAddress;
@property (nonatomic,strong) NSString *messageString;
//@property (nonatomic,strong) GCDAsyncSocket *tcpSocket;
@property (nonatomic,strong) GCDAsyncUdpSocket *udpSocket;
@property (nonatomic) BOOL connected;

@end

@implementation RSMessenger

@synthesize delegates,tag,port,remotePublicAddress,remotePrivateAddress,connectedAddress,messageString,udpSocket,connected;

+ (RSMessenger *)messengerWithPort:(uint16_t)port
{
    //static RSMessenger *messenger;
    //if (!messenger) {
        RSMessenger *messenger = [[RSMessenger alloc]init];
        messenger.delegates = [NSMutableArray array];
        //messenger.tcpSocket = [[GCDAsyncSocket alloc]initWithDelegate:messenger delegateQueue:[RSMessenger delegateQueue]];
        //[messenger.tcpSocket acceptOnPort:port error:nil];
        messenger.udpSocket = [[GCDAsyncUdpSocket alloc]initWithDelegate:messenger delegateQueue:[RSMessenger delegateQueue]];
        [messenger.udpSocket bindToPort:port error:nil];
        [messenger.udpSocket beginReceiving:nil];
        messenger.port = port;
        messenger.remotePublicAddress = [NSString string];
        messenger.remotePrivateAddress = [NSString string];
        messenger.connectedAddress = [NSString string];
    //}
    return messenger;
}

/*- (void)sendTcpMessage:(NSString *)message toHost:(NSString *)host tag:(NSInteger)tag
{
    self.tag = tag;
    messageString = message;
    host = host;
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
        [tcpSocket writeData:[NSData encryptString:messageString withKey:MESSAGE_CODE] withTimeout:30 tag:tag];
    }
}*/

- (void)sendUdpMessage:(NSString *)message toHostWithPublicAddress:(NSString *)publicAddress privateAddress:(NSString *)privateAddress tag:(NSInteger)tag
{
    self.tag = tag;
    if (!connected) {
        remotePublicAddress = publicAddress;
        remotePrivateAddress = privateAddress;
        [udpSocket sendData:[NSData encryptString:[RSMessenger messageWithIdentifier:@"CONS" arguments:@[[RSUtilities publicIpAddress],[RSUtilities privateIPAddress],publicAddress,privateAddress]] withKey:MESSAGE_CODE] toHost:SERVER_IP port:port withTimeout:30 tag:0];
        
        [udpSocket sendData:[NSData encryptString:[RSMessenger messageWithIdentifier:@"PHOLE" arguments:@[]] withKey:MESSAGE_CODE] toHost:publicAddress port:port withTimeout:30 tag:PUBLIC_ADDRESS_TAG];
        [udpSocket sendData:[NSData encryptString:[RSMessenger messageWithIdentifier:@"PHOLE" arguments:@[]] withKey:MESSAGE_CODE] toHost:privateAddress port:port withTimeout:30 tag:PRIVATE_ADDRESS_TAG];
    }
    else {
        [udpSocket sendData:[NSData encryptString:messageString withKey:MESSAGE_CODE] toHost:connectedAddress port:port withTimeout:30 tag:0];
    }
}

- (void)sendServerMessage:(NSString *)message toServerAddress:(NSString *)serverAddress tag:(NSInteger)tag
{
    self.tag = tag;
    [udpSocket sendData:[NSData encryptString:messageString withKey:MESSAGE_CODE] toHost:SERVER_IP port:port withTimeout:30 tag:0];
}

- (void)addDelegate:(id <RSMessengerDelegate>)delegate
{
    if (![delegates containsObject:delegate]) {
        [delegates addObject:delegate];
    }
}

+ (NSString *)messageWithIdentifier:(NSString *)identifier arguments:(NSArray *)arguments
{
    NSString *message = [NSString stringWithFormat:@"ID{%@}|ARG{",identifier];
    NSUInteger i = 0;
    for (NSString *argument in arguments) {
        message = [message stringByAppendingString:argument];
        if (i != arguments.count - 1) {
            message = [message stringByAppendingString:@"[;]"];
        }
        i += 1;
    }
    message = [message stringByAppendingFormat:@"}%@",MESSAGE_END];
    return message;
}

+ (NSString *)identifierOfMessage:(NSString *)message
{
    return [[message substringFromIndex:3] substringToIndex:[message rangeOfString:@"}|ARG{"].location];
}

+ (NSArray *)argumentsOfMessage:(NSString *)message
{
    NSString *argumentsString = [message substringFromIndex:[message rangeOfString:@"ARG{"].location + 4];
    NSArray *arguments = [[argumentsString substringToIndex:argumentsString.length - 1] componentsSeparatedByString:@"[;]"];
    return arguments;
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

/*#pragma mark - GCDAsyncSocketDelegate

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port
{
    [sock writeData:[NSData encryptString:messageString withKey:MESSAGE_CODE] withTimeout:30 tag:tag];
}

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
    tcpSocket.delegate = self;
    tcpSocket.delegateQueue = [RSMessenger delegateQueue];
    NSError *error;
    if (error) {
        NSLog(@"%@",error);
    }
    [tcpSocket readDataWithTimeout:-1 tag:0];
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *messageString = [NSData decryptData:data withKey:MESSAGE_CODE];
        messageString = [messageString substringToIndex:messageString.length - 1];
        NSString *messageIdentifier = [RSMessenger identifierOfMessage:messageString];
        NSArray *messageArguments = [RSMessenger argumentsOfMessage:messageString];
        for (id delegate in delegates) {
            if ([delegate respondsToSelector:@selector(messenger:didRecieveMessageWithIdentifier:arguments:tag:)]) {
                [delegate messenger:self didRecieveMessageWithIdentifier:messageIdentifier arguments:messageArguments tag:tag];
            }
        }
    });
    [tcpSocket readDataWithTimeout:-1 tag:0];
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    dispatch_async(dispatch_get_main_queue(), ^{
        for (id delegate in delegates) {
            if ([delegate respondsToSelector:@selector(messenger:didWriteDataWithTag:)]) {
                [delegate messenger:self didWriteDataWithTag:tag];
            }
        }
    });
    [tcpSocket readDataWithTimeout:-1 tag:0];
}*/

#pragma mark - GCDAsyncUdpSocketDelegate

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didSendDataWithTag:(long)tag
{
    if ((tag == PUBLIC_ADDRESS_TAG) || (tag == PRIVATE_ADDRESS_TAG)) {
        //Connection established
        connected = YES;
        if (tag == PUBLIC_ADDRESS_TAG) {
            connectedAddress = remotePublicAddress;
        }
        else if (tag == PRIVATE_ADDRESS_TAG) {
            connectedAddress = remotePrivateAddress;
        }
        [udpSocket sendData:[NSData encryptString:messageString withKey:MESSAGE_CODE] toHost:connectedAddress port:port withTimeout:30 tag:0];
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            for (id delegate in delegates) {
                if ([delegate respondsToSelector:@selector(messenger:didWriteDataWithTag:)]) {
                    [delegate messenger:self didWriteDataWithTag:tag];
                }
            }
        });
    }
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext
{
    if (!connected) {
        connected = YES;
    }
    NSString *messageString = [NSData decryptData:data withKey:MESSAGE_CODE];
    messageString = [messageString substringToIndex:messageString.length - 1];
    NSString *messageIdentifier = [RSMessenger identifierOfMessage:messageString];
    NSArray *messageArguments = [RSMessenger argumentsOfMessage:messageString];
    if ([messageIdentifier isEqualToString:@"CONC"]) {
        NSString *publicAddress = [messageArguments objectAtIndex:0];
        NSString *privateAddress = [messageArguments objectAtIndex:1];
        [udpSocket sendData:[NSData encryptString:[RSMessenger messageWithIdentifier:@"PHOLE" arguments:@[]] withKey:MESSAGE_CODE] toHost:publicAddress port:MESSAGE_PORT withTimeout:30 tag:PUBLIC_ADDRESS_TAG];
        [udpSocket sendData:[NSData encryptString:[RSMessenger messageWithIdentifier:@"PHOLE" arguments:@[]] withKey:MESSAGE_CODE] toHost:privateAddress port:MESSAGE_PORT withTimeout:30 tag:PRIVATE_ADDRESS_TAG];
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            for (id delegate in delegates) {
                if ([delegate respondsToSelector:@selector(messenger:didRecieveMessageWithIdentifier:arguments:tag:)]) {
                    [delegate messenger:self didRecieveMessageWithIdentifier:messageIdentifier arguments:messageArguments tag:tag];
                }
            }
        });
    }
}

- (void)udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError *)error
{
    connected = NO;
}

@end
