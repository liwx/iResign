//
//  ViewController.h
//  iResign
//
//  Created by liwx on 2021/2/5.
//


#import <Foundation/Foundation.h>

@interface IDRunLoop : NSObject

@property (nonatomic) BOOL isSuspend;

- (void)run:(void (^)(void))block;
- (void)stop:(void (^)(void))complete;

@end
