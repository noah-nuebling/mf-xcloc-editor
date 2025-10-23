//
//  SourceList.h
//  mf-xcloc-editor
//
//  Created by Noah Nübling on 09.06.25.
//

#import <Cocoa/Cocoa.h>

@interface SourceList : NSOutlineView <NSOutlineViewDataSource, NSOutlineViewDelegate>

- (void) setXliffDoc: (NSXMLDocument *)xliffDoc;

@end
