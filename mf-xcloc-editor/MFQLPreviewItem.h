//
//  MFQLPreviewItem.h
//  mf-xcloc-editor
//
//  Created by Noah Nübling on 10/22/25.
//

#import <Foundation/Foundation.h>
#import <QuickLookUI/QuickLookUI.h>

@interface MFQLPreviewItem : NSObject<QLPreviewItem>

    @property NSURL * previewItemURL;
    @property NSString * previewItemTitle;
    @property id previewItemDisplayState;

@end
