//
//  EZRThrottleTransform.m
//  EasyReact
//
//  Created by huangyanhua on 2018/8/29.
//

#import "EZRThrottleTransform.h"
#import "EZRNode+ProjectPrivate.h"
#import "EZRMetaMacros.h"
#import "EZRMetaMacrosPrivate.h"

@implementation EZRThrottleTransform {
@private
    NSTimeInterval _throttleInterval;
    dispatch_source_t _throttleSource;
    dispatch_queue_t _queue;
    id _lastValue;
    id _lastContext;
    EZRSenderList *_lastSenderList;
    EZR_LOCK_DEF(_sourceLock);
}

- (instancetype)initWithThrottle:(NSTimeInterval)timeInterval on:(dispatch_queue_t)queue {
    NSParameterAssert(timeInterval > 0);
    NSParameterAssert(queue);
    if (self = [super init]) {
        _throttleInterval = timeInterval;
        _queue = queue;
        EZR_LOCK_INIT(_sourceLock);
        [super setName:@"Throttle"];
    }
    return self;
}

- (void)next:(id)value from:(EZRSenderList *)senderList context:(nullable id)context {
    EZR_SCOPELOCK(_sourceLock);
    
    _lastValue = value;
    _lastContext = context;
    _lastSenderList = senderList;
    
    if (!_throttleSource) {
        _throttleSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _queue);
        dispatch_source_set_timer(_throttleSource, dispatch_time(DISPATCH_TIME_NOW, _throttleInterval * NSEC_PER_SEC), _throttleInterval * NSEC_PER_SEC, 0.005);
        @ezr_weakify(self)
        dispatch_source_set_event_handler(_throttleSource, ^{
            @ezr_strongify(self)
            if (!self) {
                return ;
            }
            EZR_SCOPELOCK(self->_sourceLock);
            if (self->_lastValue) {
                // send the latest value
                [self _superNext:self->_lastValue from:self->_lastSenderList context:self->_lastContext];
                self->_lastValue = nil;
                self->_lastSenderList = nil;
                self->_lastContext = nil;
            } else {
                dispatch_source_cancel(self->_throttleSource);
                self->_throttleSource = nil;
            }
        });
        
        dispatch_resume(_throttleSource);
    }
}

- (void)_superNext:(id)value from:(EZRSenderList *)senderList context:(nullable id)context {
    [super next:value from:senderList context:context];
}

@end
