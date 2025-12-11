//
//  NSNotificationCenter+Additions.m
//  Xcloc Editor
//
//  Created by Noah Nübling on 11/1/25.
//

#import "NSNotificationCenter+Additions.h"
#import "NSObject+MFAssociatedObject.h"
#import "Utility.h"

@interface MFNotificationObserver : NSObject @end
@implementation MFNotificationObserver
    {
        @public
        __weak id weakObservee;
        void (^block) (NSNotification *notification, id observee);
    }
    
    - (void) callback: (NSNotification *)notification {
        id strongObservee = weakObservee;
        self->block(notification, strongObservee);
    }
    
@end

@implementation NSNotificationCenter (Additions)

    - (id) mf_addObserverForName: (NSNotificationName)name object: (id)obj observee: (id)observee block: (void (^)(NSNotification * notification, id observee))block {
        
        /// Explanation:
        ///     The goal is to simplify lifetime management vs Apple's block-based NSNotificationCenter interface: `addObserverForName:object:queue:usingBlock:`.
        ///         Instead of having to manually store the observer and then call `removeObserver:` on it, you instead pass in an `observee` object which determines the lifetime of the observation.
        ///         If you pass in nil as the `observee`, the observation lives as long as the observer (which is returned from the method – you'll then have to retain it)
        ///         In contrast to `addObserverForName:object:queue:usingBlock:`, you don't have to call `removeObserver:` in any case, you can just let the observer get deallocated. (But you could also call `removeObserver:` on it to cancel it early.)
        /// Neat:
        ///     The observee is also passed to the callback-block making it easier to avoid retain-cycles, without doing the weak/strong dance.
        ///
        /// Ownership graph:
        ///     observee (owns) observer (owns) block
        ///         Or if you retain the observer (which is returned from this method): your stuff (owns) observer (owns) block.
        ///     -> As soon as the observer has no more owners, it'll get dealloc'd, and then the NSNotificationCenter will automatically cleanup the observation, the next time it tries to send to the observer.
        ///
        /// Update: [Nov 2025]
        ///     The name `observee` makes no sense,  but the API is good. Claude suggests `owner` instead.
        
        if (!block) {
            assert(false);
            return nil;
        }
        
        MFNotificationObserver *observer = [MFNotificationObserver new];
        {
            observer->block = block;
            observer->weakObservee = observee;
        }
        
        [observee
            mf_setAssociatedObject: observer
            forKey: stringf(@"%p", observer) /// Use the pointer as key –> Can have arbitrary number of observations on the observee
        ];
        
        [self addObserver: observer selector: @selector(callback:) name: name object: obj];
        
        return observer;
    }

    #if 0
        - (id<NSObject>) mf_addObserverForName: (nullable NSNotificationName)name object: (nullable id)obj observee: (nonnull id)observee block: (void (^_Nonnull )(NSNotification * _Nonnull, id observee))block {
            
            /// This is probably not safe to use for most common usecases, if this excerpt from the `addObserverForName:` docs is true:
            ///     `You must invoke NotificationCenter/removeObserver(_:) or removeObserver:name:object: before the system deallocates any object that addObserverForName:object:queue:usingBlock: specifies.`
            
            __weak id weakObservee = observee;
            __block __weak id weakObserver;
            weakObserver = [self addObserverForName: name object: obj queue: nil usingBlock: ^(NSNotification * _Nonnull notification) {
                if (!observee) /// Auto-cancel the observation when the observee gets deallocated
                    [[NSNotificationCenter defaultCenter] removeObserver: weakObserver];
                
                block(notification, observee);
            }];
            
            return weakObserver;
        }
    #endif

@end
