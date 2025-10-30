//
//  XclocDocument.m
//  mf-xcloc-editor
//
//  Created by Noah Nübling on 10/23/25.
//

///
/// See:
///     - PackagedDocument sample project (https://developer.apple.com/library/archive/samplecode/PackagedDocument/Introduction/Intro.html#//apple_ref/doc/uid/DTS40012955-Intro-DontLinkElementID_2)
///     - 
///

#import "XclocDocument.h"
#import "Utility.h"

#define kMFTypeName_Xcloc @"com.apple.xcode.xcloc"

@interface XclocDocument ()
    @property NSFileWrapper *storedXclocFileWrapper;
@end

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

    
#pragma mark - Saving
    
    #define useNativeSaving 0 /// Note: If we activate this, we should add back the default menu items like `Save`, maybe 'Revert to Version...' etc. [Oct 2025]
    
    - (void) writeTranslationDataToFile {
        /// Our code calls this whenever an edit is made
        if (!useNativeSaving)
            [self saveDocument: nil];
    }
    #if !useNativeSaving
        - (void)_updateDocumentEditedAndAnimate:(BOOL)flag {
            /// Turn off 'Edited' label flashing (since we just automatically save on every edit the user makes) – Doesn't work [Oct 2025]
            /// Works on macOS Tahoe
            ///     Src: https://stackoverflow.com/a/11998846
        }
        - (BOOL)_shouldShowAutosaveButtonForWindow: (NSWindow*)window {
            return NO;
        }
        - (void)_setShowAutosaveButton: (BOOL)flag {
            [super _setShowAutosaveButton: NO];
        }
    #endif
    
    + (BOOL) preservesVersions {
        return useNativeSaving;
    }
    + (BOOL) autosavesInPlace {
        // "Gives us autosave and versioning for free in 10.7 and later."
        /// Not sure we want this, since we just immediately save (`writeTranslationDataToFile`) on every edit. [Oct 2025]
        return useNativeSaving || YES; /// Note: Setting this to YES prevents the dot in the close button from showing, which otherwise shows after we undo. (Couldn't prevent this with the private methods (https://stackoverflow.com/a/11998846)) Hope this doesn't have other weird side effects. (Saving was so simple before NSDocument, why do they make it so complicated to just manually save?) [Oct 2025]
    }

#pragma mark - Read & Write

    - (BOOL) readFromFileWrapper: (NSFileWrapper *)xclocWrapper ofType: (NSString *)typeName error: (NSError *__autoreleasing  _Nullable *)outError {
        
        #define fail(msg...) ({ \
            mflog(msg); \
            if (outError) *outError = mferror(NSCocoaErrorDomain, 0, msg); \
            assert(false); \
            return NO; \
        })
        
        NSError *err = nil;
        
        {
            /// Load xliff
            NSXMLDocument *doc = nil;
            {
                
                auto xliffWrapper = fw_readPath(xclocWrapper, fw_getXliffPath(xclocWrapper));
                doc = [[NSXMLDocument alloc] initWithData:  xliffWrapper.regularFileContents options: NSXMLNodeOptionsNone error: &err];
                if (err) fail(@"Loading XMLDocument from wrapper '%@' failed with error: '%@'", xliffWrapper, err);
                
                mflog(@"Loaded xliff from fileWrapper %@", xliffWrapper.filename);
            }
            
            /// Load localizedStringData.plist
            NSArray *localizedStringsDataPlist = nil;
            {
                auto stringsDataPaths = fw_findPaths(xclocWrapper, ^BOOL (NSFileWrapper *w, NSString *p, BOOL *stop) {
                    if ([p hasSuffix: @"localizedStringData.plist"]) {
                        *stop = YES;
                        return YES;
                    }
                    return NO;
                });
                
                if (stringsDataPaths.count) { /// .xloc files with no screenshots don't have `localizedStringData.plist` [Oct 2025]
                    
                    localizedStringsDataPlist = [NSPropertyListSerialization
                        propertyListWithData: fw_readPath(xclocWrapper, stringsDataPaths[0]).regularFileContents
                        options: 0
                        format: NULL
                        error: &err
                    ];
                    if (err) fail(@"Loading localizedStringsData.plist from fileWrapper failed with error: %@", err);
                    
                    mflog(@"Loaded localizedStringsData.plist from fileWrapper: %@", xclocWrapper);
                }
            }
            
            /// Store deserialized data
            self->_xliffDoc = doc;
            self->_localizedStringsDataPlist = localizedStringsDataPlist;
            
            /// Store the xcloc fileWrapper directly (Used in `fileWrapperOfType:`) [Oct 2025]
            self->_storedXclocFileWrapper = xclocWrapper;
            
            /// Update the UI
            if (self->ctrl) {
                [self refreshSourceList]; /// Usually will be called by `makeWindowControllers`. But this is needed when reverting to previous version.
            }
        }
        
        return YES;
    }
    
    - (NSFileWrapper *) fileWrapperOfType: (NSString *)typeName error: (NSError *__autoreleasing  _Nullable *)outError {
        
        fw_writePath(self.storedXclocFileWrapper, fw_getXliffPath(self.storedXclocFileWrapper), [[self->_xliffDoc XMLStringWithOptions: NSXMLNodePrettyPrint] dataUsingEncoding: NSUTF8StringEncoding]);
        
        
        static int _fileWrapCounter = 0; /// Monitor if our file is consistently saved on every edit [Oct 2025]
        mflog(@"(%d) Returning fileWrapper for saving document: %@", _fileWrapCounter++, self.storedXclocFileWrapper);
        
        return self.storedXclocFileWrapper;
    }
    
    #if 0

        /// Old `-writeToURL`-based implementation
        ///     Moved to fileWrapper-based APIs instead cause it seems those are indented for folders (.xcloc files are folders)
        ///         (The `url` arg that you're supposed to write to is in some weird temp dir, not the original URL, and you'd have to write the entire bundle there including all the screenshots and other data we never wanna manipulate.)
        ///         (Modifying the .xcloc file in-place would be by far the simplest, but it seems the NSDocument APIs aren't designed around that. Not sure why – maybe using NSDocument was a mistake) [Oct 2025]
        
        - (BOOL) writeToURL: (NSURL *)url ofType: (NSString *)typeName error: (NSError *__autoreleasing  _Nullable *)outError {
            
            NSError *err = nil;
            
            {
                /// Write xliff
                NSString *xliffPath = getXliffPath([url path]); /// Don't use `self.fileURL`!

                [[self.xliffDoc XMLStringWithOptions: NSXMLNodePrettyPrint] writeToFile: xliffPath atomically: YES encoding: NSUTF8StringEncoding error: &err];
                if (err) fail(@"An error occured while writing to the xliff file: %@", err);

                mflog(@"Wrote to xliff file: %@", xliffPath);

                /// Update bundle modification date so NSDocument knows save succeeded
                [[NSFileManager defaultManager] setAttributes: @{NSFileModificationDate: [NSDate date]} ofItemAtPath: [url path] error: &err];
                if (err) fail(@"Failed to update bundle modification date: %@", err);
            }
            return YES;
            #undef fail
        }

        - (BOOL) readFromURL: (NSURL *)url ofType: (NSString *)typeName error: (NSError *__autoreleasing  _Nullable *)outError {
            
            NSError *err = nil;
            
            if ((0)) self.fileURL = url; /// Do we have to do this manually? [Oct 2025]
            
            {
                /// Load xliff
                NSXMLDocument *doc = nil;
                {
                    
                    auto xliffPath = getXliffPath([url path]); /// Don't use `self.fileURL`!
                    
                    doc = [[NSXMLDocument alloc] initWithContentsOfURL: [NSURL fileURLWithPath: xliffPath] options: NSXMLNodeOptionsNone error: &err];
                    if (err) fail(@"Loading XMLDocument from path '%@' failed with error: '%@'", xliffPath, err);
                    
                    mflog(@"Loaded xliff at %@", xliffPath);
                }
                
                /// Load localizedStringData.plist
                NSArray *localizedStringsDataPlist = nil;
                {
                    auto stringsDataPaths = findPaths(0, [url path], ^BOOL (NSString *p) {
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
    #endif

#pragma mark - Restoration
    /// See `XclocDocumentController.m` for discussion
    /// Bug: (I think `restoreDocumentWindowWithIdentifier:`) Causes app to open and immediately start edting the first row, but without selecting that row, which causes crash and is weird. (app doesn't expect to be editing a row that is not selected)
    ///     Could fix this by turning off restoration after a crash (See `XclocDocumentController`) But I instead fixed `controlTextDidEndEditing:` to handle the edge-case.
    ///         (Was using NSDocument a mistake? This used to be so easy. [Oct 2025])
    
    #if 0
        
        - (void)encodeRestorableStateWithCoder:(NSCoder *)coder backgroundQueue:(NSOperationQueue *)queue {
            mflog(@"encodeRestorableStateWithCoder:backgroundQueue:");
            [super encodeRestorableStateWithCoder: coder  backgroundQueue: queue];
        }
        - (void)encodeRestorableStateWithCoder:(NSCoder *)coder {
            mflog(@"encodeRestorableStateWithCoder:");
            [super encodeRestorableStateWithCoder: coder];
        }
    
        - (void)restoreDocumentWindowWithIdentifier:(NSUserInterfaceItemIdentifier)identifier state:(NSCoder *)state completionHandler:(void (^)(NSWindow * _Nullable, NSError * _Nullable))completionHandler {
            /// Observations:
            ///     - This calls `[NSWindow restoreStateWithCoder:]`
            ///     - This is called by: `[NSDocumentController restoreWindowWithIdentifier:state:completionHandler:]` (Override in `XclocDocumentController`)
            mflog(@"restoreDocumentWindowWithIdentifier:");
            [super restoreDocumentWindowWithIdentifier: identifier state: state completionHandler: completionHandler];
        }
        - (void)restoreStateWithCoder:(NSCoder *)coder {
            /// Called by `restoreDocumentWindowWithIdentifier:`
            mflog(@"restoreStateWithCoder:");
            [super restoreStateWithCoder: coder];
        }

        - (void)restoreUserActivityState:(NSUserActivity *)userActivity {
            assert(false); /// Never called
            mflog(@"active restore");
            [super restoreUserActivityState: userActivity];
        }
    #endif

#pragma mark - Stuff


+ (BOOL) canConcurrentlyReadDocumentsOfType: (NSString *)typeName {
    //  Turn this on for async saving allowing saving to be asynchronous, making all our
    //  save methods (dataOfType, saveToURL) to be called on a background thread.
    return YES;
}

- (void) makeWindowControllers {
    
    mflog(@"Making windowControllers");
    
    if (self->_xliffDoc == nil) {
        assert(false);
        return;
    }

    self->ctrl = [XclocWindowController new];
    [self->ctrl loadWindow]; /// Doesn't seem to be called automatically, I think this is the right place to call this but not sure [Oct 2025]

    /// Store result
    [self addWindowController: self->ctrl];
    
    /// Connect things up (Mimicking IB files in Xcode document app template)
    [self setWindow: self->ctrl.window];
    self->ctrl.window.delegate = self;
    
    /// Load UI
    [self refreshSourceList];
}

- (void) refreshSourceList {
    /// Reload Source LIst (Does this belong here?) [Oct 2025]
    
    [self->ctrl->out_sourceList setXliffDoc: self->_xliffDoc];
    [self->ctrl->out_sourceList reloadData];
}

NSString *getXliffPath(NSString *xclocPath) {
    auto xliff = findPaths(0, xclocPath, ^BOOL (NSString *p){
        return [p hasSuffix: @".xliff"];
    })[0];
    return xliff;
}

NSString *fw_getXliffPath(NSFileWrapper *xclocWrapper) {
    
    auto xliff = fw_findPaths(xclocWrapper, ^BOOL (NSFileWrapper *w, NSString *p, BOOL *stop) {
        if ([p hasSuffix: @".xliff"]) {
            *stop = YES;
            return YES;
        }
        return NO;
    })[0];
    
    return xliff;
}

@end
