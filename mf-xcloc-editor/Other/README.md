#  <#Title#>

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
