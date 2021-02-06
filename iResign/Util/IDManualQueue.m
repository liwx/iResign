//
//  ViewController.h
//  iResign
//
//  Created by liwx on 2021/2/5.
//


#import "IDManualQueue.h"

@implementation IDManualQueue {
    NSMutableArray *operations;
}

- (instancetype)init {
    if (self = [super init]) {
        operations = @[].mutableCopy;
    }
    return self;
}

- (void)addOperation:(NSOperation *)operation {
    [operations addObject:operation];
}

- (void)next {
    if (operations.count > 0) {
        NSOperation *operation = [operations objectAtIndex:0];
        operation.completionBlock = ^{
            [self->operations removeObjectAtIndex:0];
        };
        
        [operation start];
    } else {
        if (self.noOperationPerform) {
            self.noOperationPerform();
        };
    }
}

- (void)cancelAll {
    [operations removeAllObjects];
}

@end
