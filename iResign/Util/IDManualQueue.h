//
//  ViewController.h
//  iResign
//
//  Created by liwx on 2021/2/5.
//


#import <Foundation/Foundation.h>

@interface IDManualQueue : NSObject

- (void)addOperation:(NSOperation *)operation;

- (void)next;
- (void)cancelAll;

@property (nonatomic, copy) void(^noOperationPerform)(void);

@end
