//
//  RSUtilities.h
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
#import <CommonCrypto/CommonDigest.h>

/*
  This class implements all kinds of utility methods.
*/

@protocol RSIPListDelegate;

@interface RSUtilities : NSObject

/*
  Returns the addresses of all the neighbors.
*/
+ (NSArray *)localIpList;
/*
  Only returns the online neighbors' addresses.
*/
+ (NSArray *)onlineNeighbors;

/*
  Returns the neighbors with the highest probability value.The "k" value is the count of the addresses you want.
*/
+ (NSArray *)contactListWithKValue:(NSUInteger)k;
/*
  Returns the external IP address of the current device.
*/
+ (NSString *)getLocalIPAddress;

/*
  Returns the SHA-1 hash from the given string.
*/
+ (NSString *)hashFromString:(NSString *)string;
//+ (NSArray *)listOfHashedFilenames;
/*
  Returns a list of all the files under the "STORED_DATA_DIRECTORY" defined in RSConstants.h
*/
+ (NSArray *)listOfFilenames;

/*
  Returns the free disk space left in bytes.
*/
+ (uint64_t)freeDiskspace;

@end