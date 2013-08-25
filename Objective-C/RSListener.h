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
  You CAN use this class to wrap the recieved messages by using the didRecieveDataWithType:arguments method.
  You should use this class with caution:don't use identifiers that's the same as the identifiers used by RevS.
  If you want to use RSListener to handle your messages,simply change the delegate of your RSMessage object to [RSListener sharedListener]
  If you use RSListener to handle your messages,you should follow the RevS Message Protocol.Visit https://github.com/theGreatLzbdd/RevS/wiki/RevS-Message-Protocol to lern more.
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
  This is called when RSListener recieves a message.
  "type"is the identifier you use to identify the message.
  "arguments"is an array of recieved arguments.
*/
- (void)didRecieveDataWithType:(NSString *)type arguments:(NSArray *)arguments;
/*
  DON'T use the methods below.they are used by RSDownload and RSUpload. 
*/
- (void)didSaveFile:(NSString *)fileName;
- (void)didUploadFile:(NSString *)fileName;

@end
