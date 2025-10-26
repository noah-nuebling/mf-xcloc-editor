
Overview: `MMF Xcloc Editor`

    Clone of Xcode xcloc editing UI 
        
    Perks that it has in common with Xcode's xcloc editor:
        - Very simple, elegant design that gives you just what is necessary to provide great translations.
        - All localization data local to your project.
        - Easy string-state management:
            - MMF Xcloc Editor shows the 'state' of localized strings in an attractive and easy-to understand way. Users can sort by the state to quickly find all strings that need work. When users update a string, the state changes to 'translated'.
            - When you import or export localizations, Xcode synchronizes this state between the .xcstrings files in your project and the .xcloc files you send to localizers. The state is stored directly your git history and there's no synchronization with an external service like CrowdIn, which can be error-prone in my experience. Xcode updates the state of localized strings in your project automatically when you make an edit in your project or when you import an .xcloc file edited by a translator. 
        - You can include localization screenshots that show localizers exactly where the localized strings they're editing appear in the UI.
            - Note: There are old WWDC videos and Apple documentation showing how Xcode can generate these localization screenshots automatically – the format exported by Xcode is supported by this editor. 
                However, I couldn't get Xcode to generate the localization screenshots and instead implemented the localization screenshot feature manually for my app Mac Mouse Fix using XCUI Tests.
    
    Improvements over Xcode's xcloc editor:
        
        - Don't have to download Xcode (large)
        - Doesn't have Xcode sidebar which is useless to localizers
        - Allows filtering / searching in strings from *all* project files, which could e.g. help localizers easily reference how a term is localized in other parts of the app. (There's no glossary support, but this may be good enough)
        - QuickLook of localization screenshots via Space or Command-Y (Xcode has quicklook but it always has to be triggered by clicking a tiny button with the mouse which is annoying – this may be a bug)
        - Doesn't have Xcode bug where red rectangles that highlight strings in localization screenshots are never updated. [FB20608107]
            - This bug can be circumvented by including a copy of the screenshot for each localizable string that appears inside of it – however, for my app, Mac Mouse Fix, this bloats the size of the .xcloc package beyond the size supported by Gmail attachments or GitHub comment attachments – making it hard for volunteer localizers to share the .xcloc files they've translated.
        - Localizers can edit the state of localized strings
            - In Xcode, the state automatically updates to 'translated' whenever the localizer edits the string, but other than that localizers have no control over the state, e.g. if they wanna come back to a string later.
            - `MMF Xcloc Editor` lets localizers toggle the state between 'needs_review' and 'translated' – plus there's a convenient Command-R shortcut.
        - Shows localization progress percentage in the sidebar (Similar to Xcode's **.xcstrings** editor), helping localizers keep track of their progress.
        - Strings marked as 'do not translate' are *not* shown to localizers.
        - Strings with multiple pluralizable variants are displayed in a simple way. 
            Note: Pluralizable format specifiers like `%#@pluralizable@` can not be edited and are not shown to localizers. From my understanding it's never necessary to make this editable, at least for my app Mac Mouse Fix, which this editor is primarily designed for. In Mac Mouse Fix, I set the `pluralizable format string` of all pluralizable strings to to only a single format specifier (like `%#@pluralizable@`) and then have all the actual content in the plural variants. This simplifies things for localizers and has no drawbacks as far as I can tell. If somebody does need this functionality – let me know and I'll consider adding it.
        - Pluralizable variants are not hidden by default. 
            - In Xcode, users have to go through two levels of '>' disclosure triangles to see pluralizable variants, which they may miss.
        - Only once all the pluralizable variants are marked as 'translated' does the entire string show up as 'translated'
            - In Xcode, the pluralizable string can be marked as 'translated' while the variants are still marked as 'needs_review' which could be confusing.
        - Supports undo and redo for all edits.
        - Can be controlled completely via the keyboard. 
        (- Shift-Return enters a newline, for the ChatGPT users.)
        - .xcloc file automatically saves on every edit so users don't have to manually save and no data will be lost. 
        - Small size – can be shipped in a bundle with your .xcloc files.
    
    Caveats:
        - I kinda hacked this together in a few days as a hobby project. I made this specifically for the .xcloc files of my app Mac Mouse Fix, and may not work correctly with other .xcloc files. If you find some bug or incompatibility with your .xcloc files, let me know and I'll consider adding a patch. (Or just write a pull request)
        - Can't edit `pluralizable format string`s (but that shouldn't be necessary I think – see above)

--- 

Old notes

[Jun 9 2025] Tried to build an XCLOC editor. I thought maybee it's nice to not force ppls to download Xcode to translate MMF, but it's not really worth it. 
Mostly did this for fun to explore AppKit and objc a little bit.
However, I messed up the SourceList inside MainMenu.xib, but tried to undo but I think the whole file is kinda broken and slows Xcode down to a crawl. 

Lesson: IB is super brittle, and UNDO is not reliable -> So don't work on IB without a git backup.
Other uses of this proj: 
    - Perhaps send this to Apple so they can fix whatever is causing Xcode to slow-down when opening MainMenu.xib file.


Meta: 
    I also looked a bit into all the xcloc editors available on the AppStore, but none of them seem good. 
        (Wrote more about this elsewhere I think. I explored many xcloc-editor options more thoroughly some months ago. I checked a few for updates in the last few days but found nothing.)
        (IIRC, the only good editor was LocaStudio, but that got abandoned and doesn't support the new xcloc features (states))
         

---

On libs:

(I tried a bunch of XML libraries before I discovered `NSXMLDocument` exists`:)


    Built libxml2 with these options: [Jun 9 2025]

        ```
        CFLAGS='-O2 -fno-semantic-interposition' ./configure --with-legacy --with-output --with-writer --prefix=/Users/Noah/Desktop/mmf-stuff/mf-xcloc-editor/mf-xcloc-editor/libxml2-build/
        ```

        I think `--with-legacy` was necessary otherwise app crashed after launch

        ... But then I found out the macOS SDK already included libxml2 and NSXMLDocument exist.

    Also tried xml.c lib but it failed to parse my xliff file.
