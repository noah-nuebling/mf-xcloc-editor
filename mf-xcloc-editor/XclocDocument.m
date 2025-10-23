//
//  XclocDocument.m
//  mf-xcloc-editor
//
//  Created by Noah Nübling on 10/23/25.
//

#import "XclocDocument.h"
#import "Utility.h"

#define kMFTypeName_Xcloc @"com.apple.xcode.xcloc"

@implementation XclocDocument

/*
- (NSString *)windowNibName {
    // Override to return the nib file name of the document.
    // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
    return <#nibName#>;
}
*/

- (void) windowControllerDidLoadNib: (NSWindowController *)aController {
    [super windowControllerDidLoadNib:aController];
    /// Run after windowController has loaded the document's window. (Does this work for us since we're not using a nib?) [Oct 2025]
}

#pragma mark - Read & Write

    - (void) writeTranslationDataToFile {
        /// TODO: Remove (old AppDelegate interface)
        [self saveDocument: nil];
    }

    /// Alternative methods listed by Apple's NSDocument Xcode template
    /// Writing:   `-dataOfType:error:,          -fileWrapperOfType:error:,         -writeToURL:ofType:error:       -writeToURL:ofType:forSaveOperation:originalContentsURL:error:`
    /// Reading: `-readFromData:ofType:error:, -readFromFileWrapper:ofType:error: -readFromURL:ofType:error:`

    - (BOOL) writeToURL: (NSURL *)url ofType: (NSString *)typeName error: (NSError *__autoreleasing  _Nullable *)outError {
        
        #define fail(msg...) ({ \
            mflog(msg); \
            if (outError) *outError = mferror(NSCocoaErrorDomain, 0, msg); \
            assert(false); \
            return NO; \
        })
        
        NSError *err = nil;
        
        {
            /// Write xliff
            NSString *xliffPath = [url path];
            if ((0)) xliffPath = getXliffPath(self->xclocPath); /// TESTING
            
            [[self.xliffDoc XMLStringWithOptions: NSXMLNodePrettyPrint] writeToFile: xliffPath atomically: YES encoding: NSUTF8StringEncoding error: &err];
            if (err) mflog(@"An error occured while writing to the xliff file: %@", err);
            
            mflog(@"Wrote to xliff file: %@", xliffPath);
            
        }
        return YES;
        #undef fail
    }

    - (BOOL) readFromURL: (NSURL *)url ofType: (NSString *)typeName error: (NSError *__autoreleasing  _Nullable *)outError {
        
        #define fail(msg...) ({ \
            mflog(msg); \
            if (outError) *outError = mferror(NSCocoaErrorDomain, 0, msg); \
            assert(false); \
            return NO; \
        })
        
        NSError *err = nil;
        
        self->xclocPath = [url path];
        
        {
            /// Load xliff
            NSXMLDocument *doc = nil;
            {
                
                auto xliffPath = getXliffPath(xclocPath);
                
                doc = [[NSXMLDocument alloc] initWithContentsOfURL: [NSURL fileURLWithPath: xliffPath] options: NSXMLNodeOptionsNone error: &err];
                if (err) fail(@"Loading XMLDocument from path '%@' failed with error: '%@'", xliffPath, err);
                
                mflog(@"Loaded xliff at %@", xliffPath);
            }
            
            /// Load localizedStringData.plist
            NSArray *localizedStringsDataPlist = nil;
            {
                auto stringsDataPaths = findPaths(xclocPath, ^BOOL (NSString *p) {
                    return [p hasSuffix: @"localizedStringData.plist"];
                });
                if (stringsDataPaths.count) { /// .xloc files with no screenshots don't have `localizedStringData.plist` [Oct 2025]
                    auto stringsDataPath = stringsDataPaths[0];
                    
                    localizedStringsDataPlist = [[NSArray alloc] initWithContentsOfURL: [NSURL fileURLWithPath: stringsDataPath] error: &err];
                    if (err) fail(@"Loading localizedStringsData.plist failed with error: %@", err);
                    
                    mflog(@"Loaded localizedStringsData.plist at %@", stringsDataPath);
                }
            }
            
            /// Store xliff
            self.xliffDoc = doc;
            
            /// Store localizedStringsDataPlist
            self.localizedStringsDataPlist = localizedStringsDataPlist;
        }
        
        return YES;
        #undef fail
    }

#pragma mark - Stuff

+ (BOOL)autosavesInPlace {
    return YES;
}

+ (BOOL) canConcurrentlyReadDocumentsOfType: (NSString *)typeName {
    if ([typeName isEqual: kMFTypeName_Xcloc]) return YES;
    return NO;
}

- (void) makeWindowControllers {

    if (self.xliffDoc == nil) return; /// TESTING

    self->ctrl = [MainWindowController new];
    [self->ctrl loadWindow]; /// Doesn't seem to be called automatically, I think this is the right place to call this but not sure [Oct 2025]

    /// Store result
    [self addWindowController: self->ctrl];
    
    /// Connect things up (Mimicking IB files in Xcode document app template)
    [self setWindow: self->ctrl.window];
    self->ctrl.window.delegate = self;
    
    /// Reload Source LIst (Does this belong here?) [Oct 2025]
    if ((1)) {
        [self->ctrl->out_sourceList setXliffDoc: self->_xliffDoc];
        [self->ctrl->out_sourceList reloadData];
    }
    
    /// Open window (Does this belong here?)
    if ((0)) [self->ctrl.window makeKeyAndOrderFront: nil];
}
NSString *getXliffPath(NSString *xclocPath) {
    NSString *xliffPath = findPaths(xclocPath, ^BOOL (NSString *p){
        return [p hasSuffix: @".xliff"];
    })[0];
    return xliffPath;
}

@end
