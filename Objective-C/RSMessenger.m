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

static NSMutableArray *registedMessageIdentifiers;
static NSMutableArray *messageHistory;

@interface RSMessenger () <GCDAsyncSocketDelegate,GCDAsyncUdpSocketDelegate>

@property (nonatomic,strong) GCDAsyncUdpSocket *udpSocket;
@property (nonatomic) RSNatTier remoteNatTier;

@end

@implementation RSMessenger

@synthesize tag,port,udpSocket,remoteNatTier,delegate;

#pragma mark - Initializing

+ (RSMessenger *)messengerWithPort:(uint16_t)port delegate:(id <RSMessengerDelegate>)delegate;
{
    RSMessenger *messenger = [[RSMessenger alloc]init];
    messenger.delegate = delegate;
    messenger.udpSocket = [[GCDAsyncUdpSocket alloc]initWithDelegate:messenger delegateQueue:[RSMessenger delegateQueue]];
    [messenger.udpSocket bindToPort:port error:nil];
    [messenger.udpSocket beginReceiving:nil];
    messenger.port = port;
    return messenger;
}

+ (void)registerMessageIdentifiers:(NSArray *)identifiers delegate:(id)delegate
{
    if (!registedMessageIdentifiers) {
        registedMessageIdentifiers = [NSMutableArray array];
    }
    [registedMessageIdentifiers addObject:[NSDictionary dictionaryWithObjects:@[delegate,identifiers] forKeys:@[@"delegate",@"identifiers"]]];
}

#pragma mark - Sending messages

- (void)sendUdpMessage:(NSString *)message toHostWithPublicAddress:(NSString *)publicAddress privateAddress:(NSString *)privateAddress tag:(NSInteger)tag
{
    self.tag = tag;
    message = [message stringByReplacingOccurrencesOfString:@"PrivateAddress" withString:privateAddress];
    [RSMessenger addMessageWithRemotePublicAddress:publicAddress privateAddress:privateAddress message:message delegate:delegate socket:udpSocket];
    NSInteger messageTag = [messageHistory indexOfObject:[NSDictionary dictionaryWithObjects:@[publicAddress,privateAddress,message,delegate] forKeys:@[@"publicIp",@"privateIp",@"message",@"delegate"]]];
    if (![[RSUtilities connectedAddresses]containsObject:[NSString stringWithFormat:@"%@,%@",publicAddress,privateAddress]] && ([RSUtilities natTier] == RSTierUdpHolePunching || remoteNatTier == RSTierUdpHolePunching)) {
        [udpSocket sendData:[NSData encryptString:[RSMessenger messageWithIdentifier:@"COMSRVR" arguments:@[[RSUtilities publicIpAddress],[RSUtilities privateIpAddress],publicAddress,privateAddress]] withKey:MESSAGE_CODE] toHost:SERVER_IP port:port withTimeout:30 tag:messageTag];
    }
    else if ([[RSUtilities connectedAddresses]containsObject:[NSString stringWithFormat:@"%@,%@",publicAddress,privateAddress]] && ([RSUtilities natTier] == RSTierUdpHolePunching || remoteNatTier == RSTierUdpHolePunching)) {
        [udpSocket sendData:[NSData encryptString:message withKey:MESSAGE_CODE] toHost:publicAddress port:port withTimeout:30 tag:messageTag];
    }
    else if ([RSUtilities natTier] == RSTierNoNatOrNatPmp) {
        [RSUtilities addConnectedAddress:[NSString stringWithFormat:@"%@,%@",publicAddress,privateAddress]];
        [udpSocket sendData:[NSData encryptString:message withKey:MESSAGE_CODE] toHost:publicAddress port:port withTimeout:30 tag:messageTag];
    }
    else if ([RSUtilities natTier] == RSTierRelay) {
        [self sendRelayMessage:message toPublicAddress:publicAddress privateAddress:privateAddress];
    }
}

- (void)sendServerMessage:(NSString *)message toServerAddress:(NSString *)serverAddress tag:(NSInteger)tag
{
    self.tag = tag;
    [RSMessenger addMessageWithRemotePublicAddress:serverAddress privateAddress:serverAddress message:message delegate:delegate socket:udpSocket];
    [udpSocket sendData:[NSData encryptString:message withKey:MESSAGE_CODE] toHost:serverAddress port:port withTimeout:30 tag:0];
}

- (void)sendRelayMessage:(NSString *)message toPublicAddress:(NSString *)publicIp privateAddress:(NSString *)privateIp
{
    [self sendServerMessage:[RSMessenger messageWithIdentifier:@"RELAY" arguments:@[[[NSString alloc]initWithData:[NSData encryptString:message withKey:MESSAGE_CODE] encoding:NSUTF8StringEncoding],publicIp,privateIp]] toServerAddress:SERVER_IP tag:0];
}

#pragma mark - Closing

- (void)closeConnection
{
    [udpSocket closeAfterSending];
}

#pragma mark - Utilities

+ (NSString *)messageWithIdentifier:(NSString *)identifier arguments:(NSArray *)arguments
{
    NSString *message = [NSString stringWithFormat:@"ID{%@}|ARG{",identifier];
    NSInteger i = 0;
    for (NSString *argument in arguments) {
        message = [message stringByAppendingString:argument];
        if (i != arguments.count - 1) {
            message = [message stringByAppendingString:@"[;]"];
        }
        i += 1;
    }
    message = [message stringByAppendingFormat:@"}"];
    message = [message stringByAppendingFormat:@"|PIP{PrivateAddress}"];

    return message;
}

+ (NSString *)identifierOfMessage:(NSString *)message
{
    NSString *string = [message substringFromIndex:3];
    return [string substringToIndex:[string rangeOfString:@"}|ARG{"].location];
}

+ (NSArray *)argumentsOfMessage:(NSString *)message
{
    NSString *argumentsString = [message substringFromIndex:[message rangeOfString:@"ARG{"].location + 4];
    argumentsString = [argumentsString substringToIndex:[argumentsString rangeOfString:@"}|PIP{"].location];
    NSArray *arguments = [argumentsString componentsSeparatedByString:@"[;]"];
    return arguments;
}

+ (NSString *)publicIpFromMessageTag:(NSInteger)tag
{
    NSDictionary *dict = [messageHistory objectAtIndex:tag];
    return [dict objectForKey:@"publicIp"];
}

+ (NSString *)privateIpFromMessageTag:(NSInteger)tag
{
    NSDictionary *dict = [messageHistory objectAtIndex:tag];
    return [dict objectForKey:@"privateIp"];
}

+ (NSString *)messageStringFromMessageTag:(NSInteger)tag
{
    NSDictionary *dict = [messageHistory objectAtIndex:tag];
    return [dict objectForKey:@"message"];
}

+ (NSString *)delegateFromMessageTag:(NSInteger)tag
{
    NSDictionary *dict = [messageHistory objectAtIndex:tag];
    return [dict objectForKey:@"delegate"];
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

#pragma mark - Others

+ (void)addMessageWithRemotePublicAddress:(NSString *)publicIp privateAddress:(NSString *)privateIp message:(NSString *)message delegate:(id)delegate socket:(GCDAsyncUdpSocket *)sock
{
    if (!messageHistory) {
        messageHistory = [NSMutableArray array];
    }
    NSDictionary *dict = [NSDictionary dictionaryWithObjects:@[publicIp,privateIp,message,delegate,sock] forKeys:@[@"publicIp",@"privateIp",@"message",@"delegate"]];
    if (![messageHistory containsObject:dict]) {
        [messageHistory addObject:dict];
    }
}

#pragma mark - GCDAsyncUdpSocketDelegate

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didSendDataWithTag:(long)tag
{
    if ([[RSMessenger messageStringFromMessageTag:tag] rangeOfString:@"PHOLE"].length > 0) {
        //Connection established        
        [RSUtilities addConnectedAddress:[NSString stringWithFormat:@"%@,%@",[RSMessenger publicIpFromMessageTag:tag],[RSMessenger privateIpFromMessageTag:tag]]];
        [udpSocket sendData:[NSData encryptString:[RSMessenger messageStringFromMessageTag:tag] withKey:MESSAGE_CODE] toHost:[RSMessenger publicIpFromMessageTag:tag] port:port withTimeout:30 tag:tag];
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            id delegate = [RSMessenger delegateFromMessageTag:tag];
            if ([delegate respondsToSelector:@selector(messenger:didSendMessage:toPublicAddress:privateAddress:tag:)]) {
                [delegate messenger:self didSendMessage:[RSMessenger messageStringFromMessageTag:tag] toPublicAddress:[RSMessenger publicIpFromMessageTag:tag] privateAddress:[RSMessenger privateIpFromMessageTag:tag] tag:self.tag];
            }
        });
    }
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext
{
    NSString *messageString = [NSData decryptData:data withKey:MESSAGE_CODE];
    NSString *recieverPrivateIP = [messageString substringFromIndex:[messageString rangeOfString:@"|PIP{"].location + 5];
    recieverPrivateIP = [recieverPrivateIP substringToIndex:recieverPrivateIP.length - 1];
    if ([recieverPrivateIP isEqualToString:[RSUtilities privateIpAddress]] || [recieverPrivateIP isEqualToString:@"PrivateAddress"]) {
        NSString *messageIdentifier = [RSMessenger identifierOfMessage:messageString];
        NSArray *messageArguments = [RSMessenger argumentsOfMessage:messageString];
        if ([messageIdentifier isEqualToString:@"COMCLNT"]) {
            NSString *publicAddress = [messageArguments objectAtIndex:0];
            NSString *privateAddress = [messageArguments objectAtIndex:1];
            NSString *message = [RSMessenger messageWithIdentifier:@"PHOLE" arguments:@[[RSUtilities publicIpAddress],[RSUtilities privateIpAddress]]];
            [self sendUdpMessage:message toHostWithPublicAddress:publicAddress privateAddress:privateAddress tag:0];
        }
        else if ([messageIdentifier isEqualToString:@"PHOLE"])
        {
            NSString *publicAddress = [messageArguments objectAtIndex:0];
            NSString *privateAddress = [messageArguments objectAtIndex:1];
            if (![[RSUtilities connectedAddresses]containsObject:[NSString stringWithFormat:@"%@,%@",publicAddress,privateAddress]]) {
                [RSUtilities addConnectedAddress:[NSString stringWithFormat:@"%@,%@",publicAddress,privateAddress]];
                for (NSDictionary *dict in messageHistory) {
                    NSString *publicIp = [dict objectForKey:@"publicIp"];
                    NSString *privateIp = [dict objectForKey:@"privateIp"];
                    if ([publicIp isEqualToString:publicAddress] && [privateIp isEqualToString:privateAddress]) {
                        [self sendUdpMessage:[dict objectForKey:@"message"] toHostWithPublicAddress:publicAddress privateAddress:privateAddress tag:0];
                        break;
                    }
                }
            }
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                for (NSDictionary *dict in registedMessageIdentifiers) {
                    id delegate = [dict objectForKey:@"delegate"];
                    NSArray *identifiers = [dict objectForKey:@"identifiers"];
                    if ([identifiers containsObject:messageIdentifier]) {
                        if ([delegate respondsToSelector:@selector(messenger:didRecieveMessageWithIdentifier:arguments:tag:)]) {
                            [delegate messenger:self didRecieveMessageWithIdentifier:messageIdentifier arguments:messageArguments tag:tag];
                        }
                    }
                }
            });
        }
    }
    else {
        [self sendServerMessage:messageString toServerAddress:recieverPrivateIP tag:0];
    }
}

- (void)udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError *)error
{
    for (NSDictionary *dict in messageHistory) {
        GCDAsyncUdpSocket *socket = [dict objectForKey:@"socket"];
        if ([sock isEqual:socket]) {
            NSString *publicAddress = [dict objectForKey:@"publicIp"];
            NSString *privateAddress = [dict objectForKey:@"privateIp"];
            [RSUtilities removeConnectedAddress:[NSString stringWithFormat:@"%@,%@",publicAddress,privateAddress]];
        }
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([delegate respondsToSelector:@selector(messenger:connectionDidCloseWithError:)]) {
            [delegate messenger:self connectionDidCloseWithError:error];
        }
    });
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError *)error
{
    if ([RSUtilities natTier] == RSTierNoNatOrNatPmp && remoteNatTier != RSTierUdpHolePunching) {
        remoteNatTier = RSTierUdpHolePunching;
        [RSUtilities removeConnectedAddress:[NSString stringWithFormat:@"%@,%@",[RSMessenger publicIpFromMessageTag:tag],[RSMessenger privateIpFromMessageTag:tag]]];
        [self sendUdpMessage:[RSMessenger messageStringFromMessageTag:tag] toHostWithPublicAddress:[RSMessenger publicIpFromMessageTag:tag] privateAddress:[RSMessenger privateIpFromMessageTag:tag] tag:tag];
    }
    else if ([RSUtilities natTier] == RSTierUdpHolePunching || remoteNatTier == RSTierUdpHolePunching) {
        remoteNatTier = RSTierRelay;
        [self sendUdpMessage:[RSMessenger messageStringFromMessageTag:tag] toHostWithPublicAddress:[RSMessenger publicIpFromMessageTag:tag] privateAddress:[RSMessenger privateIpFromMessageTag:tag] tag:0];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([delegate respondsToSelector:@selector(messenger:didNotSendDataWithTag:error:)]) {
            [delegate messenger:self didNotSendMessage:[RSMessenger messageStringFromMessageTag:tag] toPublicAddress:[RSMessenger publicIpFromMessageTag:tag] privateAddress:[RSMessenger privateIpFromMessageTag:tag] tag:self.tag error:error];
        }
    });
}

@end
