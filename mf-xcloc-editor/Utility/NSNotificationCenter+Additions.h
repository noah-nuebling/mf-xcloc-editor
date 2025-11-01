//
//  NSNotificationCenter+Additions.h
//  MMF Xcloc Editor
//
//  Created by Noah Nübling on 11/1/25.
//

/// TODO: This is nice - Maybe move this into mac-mouse-fix

#import <Foundation/Foundation.h>

@interface NSNotificationCenter (Additions)

    - (id _Nullable) mf_addObserverForName: (nullable NSNotificationName)name object: (nullable id)obj observee: (nullable id)observee block: (void (^_Nonnull )(NSNotification *_Nonnull notification, id _Nullable observee))block;

@end
