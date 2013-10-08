//
//  RSConstants.h
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


#warning If you don't change these and publish your app with it,you might want to shoot yourself in the face LOL

#define FILE_CODE @"256-bit code"//For encrypting and decrypting files
#define MESSAGE_CODE @"256-bit code"//For encrypting and decrypting messages
#define SERVER_IP @"255.255.255.255"

//As for the constants below,change them,don't change them,it doesn't really matter
//Strings
#define IP_LIST_PATH [NSString stringWithFormat:@"%@/Documents/ipList",NSHomeDirectory()]
#define PROB_INDEX_PATH [NSString stringWithFormat:@"%@/Documents/probIndex",NSHomeDirectory()]
#define STORED_DATA_DIRECTORY [NSString stringWithFormat:@"%@/Documents/Data/",NSHomeDirectory()]

//Ports
static const uint16_t MESSAGE_PORT = 99527;
//static const uint16_t MESSAGE_PORT = 527;
//static const uint16_t MESSAGE_PORT = 805;

//Tags
static const NSInteger HOLE_PUNCH_TAG = -1;

//Numbers
static const NSInteger TTL = 6;//Time to live
static const NSInteger K = 8;//Number of neighbors to contact
static const NSInteger K_NEIGHBOR = 2;//K value applied on your neighbors during a search
static const NSInteger K_UPLOAD = 2;//K value during upload
static const NSInteger INDEX_INC = 10;
static const NSInteger NEIGHBOR_COUNT = 16;
static const NSInteger INITIAL_PROB_INDEX = 10;
static const NSInteger KEEP_ALIVE_INTERVAL = 300;
