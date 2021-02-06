//
//  ViewController.h
//  iResign
//
//  Created by liwx on 2021/2/5.
//

#import <Foundation/Foundation.h>

@interface IDDateFormatterUtil : NSObject

@property (strong, nonatomic, readonly) NSDateFormatter *dateFormatter;

+ (instancetype)sharedFormatter;

- (NSString *)timestampForDate:(NSDate *)date;

- (NSString *)MMddHHmmssSSSForDate:(NSDate *)date;

@end

