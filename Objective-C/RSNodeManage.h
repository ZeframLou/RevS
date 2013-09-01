//
//  RSNodeManage.h
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


#import <Foundation/Foundation.h>

/*
  This class implements the basic network functions,like joining and leaving the network.
*/

@interface RSNodeManage : NSObject

/*
 Returns a static RSNodeManage object.
*/
+ (RSNodeManage *)sharedInstance;

/*
  Sends a message to all the neighbors to tell them that this device is online.If the address of the device is not recorded on the server,send a message to the server too.
*/
+ (void)join;

/*
  Sends a message to all the neighbors to tell them that this device is offline.
*/
+ (void)quit;

@end
