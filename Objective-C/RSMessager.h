//
//  RSMessager.h
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

@protocol RSMessagerDelegate;

@interface RSMessager : NSObject

/*
  Initializes a RSMessager object with the given port.
*/
+ (RSMessager *)messagerWithPort:(uint16_t)port;
/*
  Send a tcp message to the specified host.The tag argument is for your own convenience,you can use it as an array index,identifier,etc.
*/
- (void)sendTcpMessage:(NSString *)message toHost:(NSString *)host tag:(NSInteger)tag;
- (void)addDelegate:(id <RSMessagerDelegate>)delegate;

@end

@protocol RSMessagerDelegate <NSObject>

@optional

/*
  Called when the messager recieved data.The tag argument is for your own convenience,you can use it as an array index,identifier,etc.
*/
- (void)messager:(RSMessager *)messager didRecieveData:(NSData *)data tag:(NSInteger)tag;
/*
  Called when the messager wrote data on a remote storage.The tag argument is for your own convenience,you can use it as an array index,identifier,etc.
*/
- (void)messager:(RSMessager *)messager didWriteDataWithTag:(NSInteger)tag;

@end
