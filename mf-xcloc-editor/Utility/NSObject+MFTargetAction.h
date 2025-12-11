//
//  NSObject+MFTargetAction.h
//  Xcloc Editor
//
//  Created by Noah Nübling on 12/11/25.
//

#import <Foundation/Foundation.h>

@interface NSObject (MFTargetAction)

    - (void) mf_bindTargetAction: (void (^)(id sender))actionCallback;

@end
