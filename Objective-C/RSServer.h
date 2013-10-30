//
//  RSServer.h
//  RevS
//
//  Created by Zebang Liu on 13-9-29.
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
  A class that does server operations.
*/

@protocol RSServerDelegate <NSObject>

@optional

- (void)serverDidRecieveMessageWithIdentifier:(NSString *)identifier arguments:(NSArray *)arguments;

@end

@interface RSServer : NSObject

/*
  Start the server to handle incoming trasmissions.
*/
+ (void)start;

/*
  Stop the server.
*/
+ (void)stop;

+ (void)listenForMessagesWithIdentifiers:(NSArray *)identifiers;

+ (void)addDelegate:(id)delegate;
+ (BOOL)isStarted;

@end
