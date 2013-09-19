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

static const NSString *FILE_CODE = @"just a simple code(you need to change this into a 256 bit password)";//For encrypting and decrypting files
static const NSString *MESSAGE_CODE = @"just a simple code(you need to change this into a 256 bit password)";//For encrypting and decrypting messages
static const NSString *SERVER_IP = @"127.0.0.1";

//As for the constants below,change them,don't change them,it doesn't really matter
//Strings
#define IP_LIST_PATH [NSString stringWithFormat:@"%@/Documents/ipList",NSHomeDirectory()]
#define PROB_INDEX_PATH [NSString stringWithFormat:@"%@/Documents/probIndex",NSHomeDirectory()]
#define STORED_DATA_DIRECTORY [NSString stringWithFormat:@"%@/Documents/Data/",NSHomeDirectory()]
#define MESSAGE_END @"\n"

//Ports
static const uint16_t MESSAGE_PORT = 99;
//static const uint16_t MESSAGE_PORT = 527;
//static const uint16_t MESSAGE_PORT = 805;

//Tags
static const NSInteger KEEP_ALIVE_TAG = 17;
static const NSInteger DOWNLOAD_TAG = 99;
static const NSInteger UPLOAD_TAG = 111;
static const NSInteger PUBLIC_ADDRESS_TAG = 1214;

//Numbers
static const NSInteger TTL = 6;//Time to live
static const NSInteger K = 8;//Number of neighbors to contact
static const NSInteger K_NEIGHBOR = 2;//K value applied on your neighbors during a search
static const NSInteger K_UPLOAD = 2;//K value during upload
static const NSInteger INDEX_INC = 10;
static const NSInteger NEIGHBOR_COUNT = 16;
static const NSInteger INITIAL_PROB_INDEX = 10;
static const NSInteger KEEP_ALIVE_INTERVAL = 300;
