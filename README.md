# Overview: `Xcloc Editor.app`

Lightweight clone of Xcode's .xcloc file editor for the Mac Mouse Fix project.

## Comparison with Xcode's xcloc editor

### Perks that it has in common with Xcode's xcloc editor

- Very simple, elegant design that gives you just what is necessary to provide great translations.
- All localization data local to your project.
- Easy string-state management:
    - Xcloc Editor.app shows the 'state' of localized strings in an attractive and easy-to understand way. Users can sort by the state to quickly find all strings that need work. When users update a string, the state changes to 'translated'.
    - When you import or export localizations, Xcode synchronizes this state between the .xcstrings files in your project and the .xcloc files you send to localizers. The state is stored directly your git history and there's no synchronization with an external service like CrowdIn, which can be error-prone in my experience. Xcode updates the state of localized strings in your project automatically when you make an edit in your project or when you import an .xcloc file edited by a translator.
- You can include localization screenshots that show localizers exactly where the localized strings they're editing appear in the UI.
    - Note: There are old WWDC videos and Apple documentation showing how Xcode can generate these localization screenshots automatically – the format exported by Xcode is supported by this editor. However, I couldn't get Xcode to generate the localization screenshots and instead implemented the localization screenshot feature manually for my app Mac Mouse Fix using XCUI Tests.

### Improvements over Xcode's xcloc editor

- Don't have to download Xcode (large)
- Small size – can be shipped in a bundle with your .xcloc files.
- Doesn't have Xcode sidebar which is useless to localizers and may be intimidating.
- All project files are layed out flat in the sidebar, so localizers don't have to search through the folder hierarchy in your project.
- Allows filtering / searching in strings from *all* project files, which could e.g. help localizers easily reference how a term is localized in other parts of the app. (There's no glossary support, but this may be good enough)
- QuickLook of localization screenshots via Space or Command-Y (Xcode has quicklook but it always has to be triggered by clicking a tiny button with the mouse which is annoying – this may be a bug, but it's been there for a long time)
- Doesn't have Xcode bug where red rectangles that highlight strings in localization screenshots are never updated. [FB20608107]
    - This bug can be circumvented by including a copy of the screenshot for each localizable string that appears inside of it – however, for my app, Mac Mouse Fix, this bloats the size of the .xcloc package beyond the size supported by Gmail attachments or GitHub comment attachments – making it hard for volunteer localizers to share the .xcloc files they've translated.
- Localizers can edit the 'state' of localized strings
    - In Xcode, the state automatically updates to 'translated' whenever the localizer edits the string, but other than that localizers have no control over the state, which could be useful if they want to come back to a string later.
    - In contrast, `Xcloc Editor.app` lets localizers easily toggle the state between 'needs_review' and 'translated' via a convenient Command-R shortcut, or an easy-to-discover right-click menu.
- Shows localization progress percentage in the sidebar (Similar to Xcode's **.xcstrings** editor), helping localizers keep track of their progress.
- Strings marked as 'do not translate' are *not* shown to localizers.
    - Xcode sorts these strings above 'needs_review' strings making it harder to find strings that need review.
- Strings with multiple pluralizable variants are displayed in a simple way.
    - Please note: 
    In `Xcloc Editor.app`, pluralizable format specifiers like `%#@pluralizable@` can not be edited and are not shown to localizers. From my understanding it's never necessary to make this editable, at least for my app Mac Mouse Fix, which this editor is primarily designed for. In Mac Mouse Fix, I set the *pluralizable format string* of all pluralizable strings to only a single format specifier (like `%#@pluralizable@`) and then have all the actual content in the plural variants. This simplifies things for localizers and has no drawbacks as far as I can tell. If somebody does need this functionality – let me know and I'll consider adding it.
- Pluralizable variants are not hidden by default.
    - In Xcode, users have to go through two levels of '>' disclosure triangles to see pluralizable variants, which they may miss.
- Only once all the pluralizable variants are marked as 'translated' does the entire string show up as 'translated'
    - In Xcode, the pluralizable string can be marked as 'translated' while the variants are still marked as 'needs_review'. This can make the strings hard to find.
- Better comments for Interface Builder strings
    - For localizable strings inside Interface Builder files, Xcode exports very long comments that are actually old-style plist dictionaries containing mostly redundant or irrelevant information such as "ObjectID", "Class" or "title" (which just repeats the English UI string). `Xcloc Editor.app` filters out all this redundant stuff, so that localizers can focus on the hints that you wrote for them.
- When you ship `Xcloc Editor.app` next to .xcloc files, it will automatically show the user a picker between those .xcloc files.
- Supports undo and redo for all edits.
- Can be controlled and navigated completely via the keyboard.
- Shift-Return enters a newline, for the ChatGPT users.
- .xcloc file automatically saves on every edit so users don't have to manually save and no data will be lost.
- Window and column resizing is less annoying than in Xcode
- Text-substitutions can be turned off.
    (E.g. smart-quotes, or "omw" -> "on my way". These always auto re-enable in Xcode.)
- Elegant '↩' marker so that localizers can easily distinguish between '\n' characters in the text vs line wrapping.

### Drawbacks compared to Xcode's xcloc editor

- Can't edit "pluralizable format string"s (but that isn't necessary I think – see above)
- Format specifiers like "%@" don't get a special color background like they do in Xcode.
    - I don't think this is super helpful in Xcode especially since it also makes it impossible to edit the format specifier once it has the background which is a bit annoying. And for my project MMF, there are Javascript, Python and C format specifiers, which won't all get highlighted consistently by Xcode anyways. So I decided to just leave this feature out. Let me know if you want this feature.

## Comparison with other xcloc editors

- The only native macOS xcloc editor that I came across and liked is [LocaStudio](https://www.cunningo.com/locastudio/index.html). It's very good but has been abandoned and doesn't support the very useful 'state' feature IIRC. (Where strings can be marked as 'needs_review' or 'translated' – see above.)
- Comparison with online editors (like CrowdIn): 
  - These might be a better alternative for most projects. 
  - Reasons why I decided against them:
      - I personally didn't like the UI of most, which I perceived to be too complex. I thought Xcode's xcloc editor was much simpler without lacking important features.
      - I didn't wanna add a dependeny on an external service, which wants to integrate with your GitHub. 
      - I liked the idea of having all the data in my git history under my control and depending only on Apple's tooling. I also had a very buggy experience with CrowdIn's git-integration which put me off.
      - I also thought that my project Mac Mouse Fix wouldn't qualify for CrowdIn's free tier since it's monetized, but they talked to me via email and that was not true! 
          - -> CrowdIn DOES offer the free-tier to smaller indie apps even if they are monetized.
      - I also wasn't aware of the issues with Xcode's xcloc editor, which caused me to write this program, `Xcloc Editor.app`.
      - I looked at some CrowdIn projects and IIRC I didn't see much 'crowd' activity even on larger projects       - Instead I saw a few people making larger contributions, which would most features and perks of online-editors not-so-relevant.
  - Was this a good choice not to go with an online editor? 
    - I'm not sure, yet. 
    - Would I recommend it?
      - If all the translatable files of your project are managed by Xcode (.xcstrings or .strings), then using `Xcloc Editor.app` might be easier to get started, lower the complexity and dependencies in your project, and provide a better experience for localizers than an online editor. But if your project contains other files, things get more complicated. For my project Mac Mouse Fix, I wrote Python scripts that call Apple's `xcstringstool` to translate *all* the project files using .xcstrings files, which can then be exported as .xcloc files. However, this was quite an effort, and it's probably less effort to use an online editor which already supports different file-types. 

## Other Caveats

I made this specifically for the .xcloc files of my app Mac Mouse Fix.
I'm not sure if anybody else will every want to use this for their project, so I didn't do extensive testing. 

If there's a problem with your .xcloc files or if you'd like to see a feature, feel free to let me know or open a pull request!

## Building

Just open in Xcode and hit the play button. If there are problems let me know. 

## Shipping

I'll consider uploading a notarized version under "Releases" [Oct 2025].
You could download this and send it to your localizers alongside your .xcloc files.
