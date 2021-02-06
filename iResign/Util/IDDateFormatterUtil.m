//
//  ViewController.h
//  iResign
//
//  Created by liwx on 2021/2/5.
//


#import "IDDateFormatterUtil.h"

@implementation IDDateFormatterUtil

#pragma mark - Initialization
static IDDateFormatterUtil *istance;
+ (instancetype)sharedFormatter {
    @synchronized(self) {
        if(istance == nil) {
            istance = [[IDDateFormatterUtil alloc] init];
            return istance;
        }
    }
    return istance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _dateFormatter = [[NSDateFormatter alloc] init];
        [_dateFormatter setLocale:[NSLocale currentLocale]];
    }
    return self;
}

- (void)dealloc {
    _dateFormatter = nil;
}

#pragma mark - Formatter
- (NSString *)timestampForDate:(NSDate *)date {
    if (!date) {
        return nil;
    }
    
    [self.dateFormatter setDateStyle:NSDateFormatterMediumStyle];
    [self.dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
    return [self.dateFormatter stringFromDate:date];
}

- (NSString *)MMddHHmmssSSSForDate:(NSDate *)date {
    if (!date) {
        return nil;
    }
    
    self.dateFormatter.dateFormat = @"MM/dd HH:mm:ss SSS";
    return [self.dateFormatter stringFromDate:date];
}


@end
