//
//  RSListener.h
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
  This is a class to handle recieved messages for other classes in RevS.
  You should NOT use this class.
*/

@protocol RSListenerDelegate;
@class RSMessenger;

@interface RSListener : NSObject

@property (nonatomic,strong) NSMutableArray *delegates;

/*
 Returns a static RSListener object.
*/
+ (RSListener *)sharedListener;
+ (void)addDelegate:(id <RSListenerDelegate>)delegate;

@end

@protocol RSListenerDelegate <NSObject>

@optional

/*
  DON'T use the methods below.they are used by RSDownload and RSUpload. 
*/
- (void)didSaveFile:(NSString *)fileName;
- (void)didUploadFile:(NSString *)fileName;

@end
