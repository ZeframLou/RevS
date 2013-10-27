//
//  RSDownload.h
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

@protocol RSDownloadDelegate;

@interface RSDownload : NSObject

/*
  Returns a static RSDownload object.
*/
+ (RSDownload *)sharedInstance;

/*
  Start a search query,if the file is found,then download the file.
*/
+ (void)downloadFile:(NSString *)fileName;

/*
  Download a file from a specific address.
*/
+ (void)downloadFile:(NSString *)fileName fromPublicAddress:(NSString *)publicAddress privateAddress:(NSString *)privateAddress;

+ (void)addDelegate:(id <RSDownloadDelegate>)delegate;

@end

@protocol RSDownloadDelegate <NSObject>

@optional

/*
 Called after a file is downloaded.
 */
- (void)didDownloadFile:(NSString *)fileName fromPublicAddress:(NSString *)publicAddress privateAddress:(NSString *)privateAddress;

/*
 Called after a download request failed.
 */
- (void)downloadDidFail:(NSString *)fileName;

@end