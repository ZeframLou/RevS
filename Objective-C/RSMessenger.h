//
//  RSMessenger.h
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


#import <Foundation/Foundation.h>

/*
  This class allows you to send and recieve messages.
*/

@protocol RSMessengerDelegate;

@interface RSMessenger : NSObject

/*
  Initializes a RSMessenger object with the given port.
*/
+ (RSMessenger *)messengerWithPort:(uint16_t)port delegate:(id <RSMessengerDelegate>)delegate;

/*
  Send a message to the specified host.This method uses udp hole punching in order to bypass the NAT.The tag argument is for your own convenience,you can use it as an array index,identifier,etc.
*/
//- (void)sendTcpMessage:(NSString *)message toHost:(NSString *)host tag:(NSInteger)tag;
- (void)sendUdpMessage:(NSString *)message toHostWithPublicAddress:(NSString *)publicAddress privateAddress:(NSString *)privateAddress tag:(NSInteger)tag;

/*
  Send a message to the server.The difference between this method and sendUdpMethod:toHost:tag: is that this method doesn't use udp hole punching.
*/
- (void)sendServerMessage:(NSString *)message toServerAddress:(NSString *)serverAddress tag:(NSInteger)tag;

/*
  Close all of the messenger's connections.Note:if the messenger is sending data when you call this method,the connection will be closed after the data has been sent.
*/
- (void)closeConnection;

/*
  Returns a formatted message following the RevS Message Protocol(RSMP).Visit https://github.com/theGreatLzbdd/RevS/wiki/RevS-Message-Protocol to learn more.
*/
+ (NSString *)messageWithIdentifier:(NSString *)identifier arguments:(NSArray *)arguments;

/*
  Returns the identifier in a message string following the RevS Message Protocol(RSMP).Visit https://github.com/theGreatLzbdd/RevS/wiki/RevS-Message-Protocol to learn more.
*/
+ (NSString *)identifierOfMessage:(NSString *)message;

/*
  Returns the arguments in a message string following the RevS Message Protocol(RSMP).Visit https://github.com/theGreatLzbdd/RevS/wiki/RevS-Message-Protocol to learn more.
*/
+ (NSArray *)argumentsOfMessage:(NSString *)message;

/*
  Registers message identifiers so that when a message is recieved,RSMessenger will be able to pass it to the right object.
*/
+ (void)registerMessageIdentifiers:(NSArray *)identifiers delegate:(id)delegate;

@end

@protocol RSMessengerDelegate <NSObject>

@optional

/*
  Called when the messenger recieved data.The tag argument is for your own convenience,you can use it as an array index,identifier,etc.
*/
- (void)messenger:(RSMessenger *)messenger didRecieveMessageWithIdentifier:(NSString *)identifier arguments:(NSArray *)arguments tag:(NSInteger)tag;

/*
  Called when the messenger wrote data on a remote storage.The tag argument is for your own convenience,you can use it as an array index,identifier,etc.
*/
- (void)messenger:(RSMessenger *)messenger didSendMessage:(NSString *)message toPublicAddress:(NSString *)publicAddress privateAddress:(NSString *)privateAddress tag:(NSInteger)tag;

/*
  Called when the messenger's connection has been closed.If the connection was closed by calling closeConnection,the "error" value will be nil.
*/
- (void)messenger:(RSMessenger *)messenger connectionDidCloseWithError:(NSError *)error;

/*
  Called if a message was not sent successfully.
*/
- (void)messenger:(RSMessenger *)messenger didNotSendDataWithTag:(NSInteger)tag error:(NSError *)error;

@end
