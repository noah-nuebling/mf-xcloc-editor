//
//  AppDelegate.h
//  mf-xcloc-editor
//
//  Created by Noah Nübling on 08.06.25.
//

#import <Cocoa/Cocoa.h>
#import "TableView.h"
#import "SourceList.h"
#import "MainWindowController.h"

#define appdel ((AppDelegate *)NSApp.delegate) /// Use this to access global state around the app

typedef struct {

} GlobalOutlets; /// Objects that we want to be available everywhere in the app

@interface AppDelegate : NSObject <NSApplicationDelegate>
    {
        @public
        MainWindowController *mainController;
        SourceList *sourceList;
        TableView *tableView;
        NSString *xclocPath;
    }
    
    - (void) writeTranslationDataToFile; /// Little weird for this to be on AppDelegate [Oct 2025]

@end

