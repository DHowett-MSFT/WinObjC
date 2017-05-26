//******************************************************************************
//
// Copyright (c) 2015 Microsoft Corporation. All rights reserved.
//
// This code is licensed under the MIT License (MIT).
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//******************************************************************************

#import <Foundation/NSNotificationQueue.h>
#import <StubReturn.h>
#import <Starboard/SmartTypes.h>

@interface NSNotificationQueue () {
    StrongId<NSNotificationCenter> _notificationCenter;
    StrongId<NSMutableArray<NSNotification*>> _asapQueue;
    StrongId<NSMutableArray<NSNotification*>> _idleQueue;
}
@end

@implementation NSNotificationQueue
/**
 @Status Interoperable
*/
+ (NSNotificationQueue*)defaultQueue {
    @synchronized(self) {
        NSNotificationQueue* threadQueue = [[[NSThread currentThread] threadDictionary] objectForKey:self];
        if (!threadQueue) {
            threadQueue = [[[NSNotificationQueue alloc] initWithNotificationCenter:[NSNotificationCenter defaultCenter]] autorelease];
            [[[NSThread currentThread] threadDictionary] setObject:threadQueue forKey:self];
        }
        return [[threadQueue retain] autorelease];
    }
}

/**
 @Status Interoperable
*/
- (instancetype)initWithNotificationCenter:(NSNotificationCenter*)notificationCenter {
    if (self = [super init]) {
        _notificationCenter = notificationCenter;
        _asapQueue.attach([NSMutableArray new]);
        _idleQueue.attach([NSMutableArray new]);
    }
    return self;
}

/**
 @Status Caveat
 @Notes Does not coalesce notifications.
*/
- (void)enqueueNotification:(NSNotification*)notification postingStyle:(NSPostingStyle)postingStyle {
    [self enqueueNotification:notification
                 postingStyle:postingStyle
                 coalesceMask:(NSNotificationCoalescingOnName | NSNotificationCoalescingOnSender)
                     forModes:nil];
}

/**
 @Status Caveat
 @Notes Ignores the coalescing mask and the runloop modes.
*/
- (void)enqueueNotification:(NSNotification*)notification
               postingStyle:(NSPostingStyle)postingStyle
               coalesceMask:(NSNotificationCoalescing)coalesceMask
                   forModes:(NSArray*)modes {
    if (!notification) {
        [NSException raise:NSInvalidArgumentException format:@"*** %s: notification must not be nil", __PRETTY_FUNCTION__];
    }

    if (!modes) {
        modes = @[ NSDefaultRunLoopMode ];
    }

    if (postingStyle == NSPostNow) {
        [_notificationCenter postNotification:notification];
        return;
    }

    NSMutableArray<NSNotification*>* queue = nil;

    switch (postingStyle) {
        case NSPostASAP:
            queue = _asapQueue;
            break;
        case NSPostWhenIdle:
            queue = _idleQueue;
            break;
        default:
            [NSException raise:NSInvalidArgumentException format:@"*** %s: unknown posting style %u", __PRETTY_FUNCTION__, (unsigned /* int */)postingStyle];
            break;
    }

    @synchronized(queue) {
        [queue addObject:notification];
    }
}

/**
 @Status Stub
 @Notes Doesn't unqueue anything.
*/
- (void)dequeueNotificationsMatching:(NSNotification*)notification coalesceMask:(NSUInteger)coalesceMask {
    UNIMPLEMENTED();
}

- (void)_drainQueue:(NSMutableArray<NSNotification*>*)queue {
    StrongId<NSArray> queueCopy{ woc::TakeOwnership, [queue copy] };
    // If the notification triggers another spin of the run loop (it shouldn't),
    // we don't want to double-fire this set of notifications.
    [queue removeAllObjects];

    for (NSNotification* notification in queueCopy.get()) {
        [_notificationCenter postNotification:notification];
    }
}

/**
 @Status Stub
 @Public No
 @Notes This method is used by NSRunLoop as part of proper dispatch of queued notifications.
        It ignores the run loop mode.
*/
- (void)asapProcessMode:(NSRunLoopMode)mode {
    if ([_asapQueue count] > 0) {
        [self _drainQueue:_asapQueue];
    }
}

/**
 @Status Caveat
 @Public No
 @Notes This method is used by NSRunLoop as part of proper dispatch of queued notifications.
        It ignores the run loop mode.
*/
- (BOOL)hasIdleNotificationsInMode:(NSRunLoopMode)mode {
    return [_idleQueue count] > 0;
}

/**
 @Status Stub
 @Public No
 @Notes This method is used by NSRunLoop as part of proper dispatch of queued notifications.
        It ignores the run loop mode.
*/
- (void)idleProcessMode:(NSRunLoopMode)mode {
    if ([_idleQueue count] > 0) {
        [self _drainQueue:_idleQueue];
    }
}

@end
