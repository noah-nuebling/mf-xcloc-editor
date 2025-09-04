//
//  AppDelegate.h
//  mf-xcloc-editor
//
//  Created by Noah Nübling on 08.06.25.
//

#import <Cocoa/Cocoa.h>
#import "TableView.h"
#import "SourceList.h"

#define appdel ((AppDelegate *)NSApp.delegate) /// Use this to access global state around the app

@interface AppDelegate : NSObject <NSApplicationDelegate>

    @property (strong) IBOutlet NSWindow *window;                         /// [Jun 2025] weak or strong? Internet says always use strong unless you need to have reference cycle: https://stackoverflow.com/a/31395938/10601702. But Xcode defaults to weak?
    @property (strong) IBOutlet SourceList *sourceList;
    @property (strong) IBOutlet TableView *tableView;

@end

