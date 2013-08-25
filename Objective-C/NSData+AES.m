//
//  NSData+AES.m
//  Novelize
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

#import <CommonCrypto/CommonCryptor.h>
@implementation NSData (AESAdditions)
- (NSData*)AES256EncryptWithKey:(NSString*)key {
// 'key' should be 32 bytes for AES256, will be null-padded otherwise
char keyPtr[kCCKeySizeAES256 + 1]; // room for terminator (unused)
bzero(keyPtr, sizeof(keyPtr)); // fill with zeroes (for padding)

// fetch key data
[key getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];

NSUInteger dataLength = [self length];

//See the doc: For block ciphers, the output size will always be less than or
//equal to the input size plus the size of one block.
//That's why we need to add the size of one block here
size_t bufferSize           = dataLength + kCCBlockSizeAES128;
void* buffer                = malloc(bufferSize);

size_t numBytesEncrypted    = 0;
CCCryptorStatus cryptStatus = CCCrypt(kCCEncrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                                      keyPtr, kCCKeySizeAES256,
                                      NULL /* initialization vector (optional) */,
                                      [self bytes], dataLength, /* input */
                                      buffer, bufferSize, /* output */
                                      &numBytesEncrypted);

if (cryptStatus == kCCSuccess)
{
    //the returned NSData takes ownership of the buffer and will free it on deallocation
    return [NSData dataWithBytesNoCopy:buffer length:numBytesEncrypted];
}

free(buffer); //free the buffer;
return nil;
}

- (NSData*)AES256DecryptWithKey:(NSString*)key {
    // 'key' should be 32 bytes for AES256, will be null-padded otherwise
    char keyPtr[kCCKeySizeAES256 + 1]; // room for terminator (unused)
    bzero(keyPtr, sizeof(keyPtr)); // fill with zeroes (for padding)
    
    // fetch key data
    [key getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];
    
    NSUInteger dataLength = [self length];
    
    //See the doc: For block ciphers, the output size will always be less than or
    //equal to the input size plus the size of one block.
    //That's why we need to add the size of one block here
    size_t bufferSize           = dataLength + kCCBlockSizeAES128;
    void* buffer                = malloc(bufferSize);
    
    size_t numBytesDecrypted    = 0;
    CCCryptorStatus cryptStatus = CCCrypt(kCCDecrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                                          keyPtr, kCCKeySizeAES256,
                                          NULL /* initialization vector (optional) */,
                                          [self bytes], dataLength, /* input */
                                          buffer, bufferSize, /* output */
                                          &numBytesDecrypted);
    
    if (cryptStatus == kCCSuccess)
    {
        //the returned NSData takes ownership of the buffer and will free it on deallocation
        return [NSData dataWithBytesNoCopy:buffer length:numBytesDecrypted];
    }
    
    free(buffer); //free the buffer;
    return nil;
}
+ (NSData*) encryptString:(NSString*)plaintext withKey:(NSString*)key {    
    return [[plaintext dataUsingEncoding:NSUTF8StringEncoding] AES256EncryptWithKey:key];
}

+ (NSString*) decryptData:(NSData*)ciphertext withKey:(NSString*)key {    
    return [[NSString alloc] initWithData:[ciphertext AES256DecryptWithKey:key]
                                 encoding:NSUTF8StringEncoding];
}
@end
