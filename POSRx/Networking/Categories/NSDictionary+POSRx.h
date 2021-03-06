//
//  NSDictionary+POSRx.h
//  POSRx
//
//  Created by Pavel Osipov on 18.06.15.
//  Copyright (c) 2015 Pavel Osipov. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSDictionary (POSRx)

/// @return Merged dictionary where target dictionary override source dictionary.
+ (nullable NSDictionary *)posrx_merge:(nullable NSDictionary *)sourceDictionary
                                  with:(nullable NSDictionary *)targetDictionary;

/// @brief Encodes parameters in query string of &-concatenated key-value pairs.
/// @return NSData of UTF8 encoded string.
- (NSData *)posrx_URLQueryBody;

/// @brief Encodes parameters in JSON.
/// @return NSData of JSON encoded dictionary.
- (NSData *)posrx_URLJSONBody;

/// @brief Encodes parameters in query string of &-concatenated key-value pairs.
/// @return Percent escaped query string for URL.
- (NSString *)posrx_URLQuery;

/// @brief Encodes parameters in query string of &-concatenated key-value pairs.
- (NSString *)posrx_URLQueryUsingPercentEncoding:(BOOL)usePercentEncoding;

@end

NS_ASSUME_NONNULL_END
