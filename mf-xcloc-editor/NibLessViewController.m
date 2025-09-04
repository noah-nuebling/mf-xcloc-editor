//
//  NibLessViewController.m
//  mf-xcloc-editor
//
//  Created by Noah Nübling on 9/5/25.
//

#import "NibLessViewController.h"

@implementation NibLessViewController
    {
        NSView *_view;
    }
    
    + (instancetype) newWithView: (NSView *)view { return [[self alloc] initWithView: view]; }
    - (instancetype) initWithView: (NSView *)view {

        self = [super initWithNibName: nil bundle: nil];
        if (!self) return nil;
        self->_view = view;
        
        return self;
    }
    
    - (void)loadView {
        [self setView: self->_view]; /// Not sure this makes any sense.
    }

@end
