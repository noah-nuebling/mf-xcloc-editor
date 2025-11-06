# Xcloc Editor.app

Lightweight clone of Xcode's .xcloc file editor for the Mac Mouse Fix project.

<img width="1440" height="900" alt="Screenshot 2025-11-05 at 9 25 58 PM" src="https://github.com/user-attachments/assets/3f328804-4840-4320-8d28-123d3a374484" />

For more on xcloc files (aka Xcode Localization Catalogs), see:\
https://developer.apple.com/documentation/xcode/exporting-localizations/

## Notes for people who may want to use this for their project as well

These notes are a bit sloppy and stream-of-consciousness, but I hope they are still useful to someone!

### Comparison with Xcode's xcloc editor

#### Perks that it has in common with Xcode's xcloc editor

- Very simple, elegant design that gives translators just what is necessary to provide great translations.
- All localization data local to your project.
- Easy string-state management:
    - Xcloc Editor.app shows the 'state' of localized strings in an attractive and easy-to understand way. Users can sort by the state to quickly find all strings that need work. When users update a string, the state changes to 'translated'.
    - When you import or export localizations, Xcode synchronizes this state between the .xcstrings files in your project and the .xcloc files you send to localizers. The state is stored directly your git history and there's no synchronization with an external service like CrowdIn, which can be error-prone in my experience. Xcode updates the state of localized strings in your project automatically when you make an edit in your project or when you import an .xcloc file edited by a translator.
- You can include localization screenshots that show localizers exactly where the localized strings they're editing appear in the UI.
    - Note: There are old WWDC videos and Apple documentation showing how Xcode can generate these localization screenshots automatically – the format exported by Xcode is supported by this editor. However, I couldn't get Xcode to generate the localization screenshots and instead implemented the localization screenshot feature manually for my app Mac Mouse Fix using XCUI Tests and Python scripts.

#### Improvements over Xcode's xcloc editor

- Don't have to download Xcode (large)
- Small size – can be shipped in a bundle with your .xcloc files.
- Doesn't have Xcode sidebar which is useless to localizers and may be intimidating.
- All project files are layed out flat in the sidebar, so localizers don't have to search through the folder hierarchy in your project.
- Easy and powerful filtering / searching in strings from *all* project files, which could e.g. help localizers easily reference how a term is localized in other parts of the app. (There's no glossary support, but this may be good enough)
- QuickLook of localization screenshots via Space or Command-Y 
    (Xcode has quicklook but it always has to be triggered by clicking a tiny button with the mouse which is annoying – this may be a bug, but it's been there for a long time)
- Doesn't have Xcode bug where red rectangles that highlight strings in localization screenshots are never updated. [FB20608107]
    - This bug can be circumvented by including a copy of the screenshot for each localizable string that appears inside of it – however, for my app, Mac Mouse Fix, this bloats the size of the .xcloc package beyond the size supported by Gmail attachments or GitHub comment attachments – making it hard for volunteer localizers to share the .xcloc files they've translated.
- Localizers can edit the 'state' of localized strings
    - In Xcode, the state automatically updates to 'translated' whenever the localizer edits the string, but other than that localizers have no control over the state.
    - In contrast, `Xcloc Editor.app` lets localizers easily toggle the state between 'needs_review' and 'translated' via a convenient Command-R shortcut, or an easy-to-discover right-click menu. -> This is useful if a localizer wants to come back to a string later.
- Shows localization progress percentage in the sidebar (Similar to Xcode's **.xcstrings** editor), helping localizers keep track of their progress.
- Strings marked as 'do not translate' are *not* shown to localizers.
    - Xcode sorts these strings above 'needs_review' strings making it harder to find strings that need review.
- Strings with multiple pluralizable variants are displayed in a simple way.
    - Caveat: In `Xcloc Editor.app`, pluralizable format specifiers like `%#@pluralizable@` can not be edited and are not shown to localizers. From my understanding it's never necessary to make this editable, at least for my app Mac Mouse Fix, which this editor is primarily designed for. In Mac Mouse Fix, I set the format string of all pluralizable strings to only a single format specifier (like `%#@pluralizable@`) and then have all the actual content in the plural variants. This simplifies things for localizers and has no drawbacks as far as I can tell. If somebody does need this functionality – [open an issue](https://github.com/noah-nuebling/mf-xcloc-editor/issues/new) and I'll consider adding it.
- Pluralizable variants are not hidden by default.
    - In Xcode, users have to go through two levels of '>' disclosure triangles to see pluralizable variants, which they may miss.
- Only once all the pluralizable variants are marked as 'translated' does the entire string show up as 'translated'
    - In Xcode, the pluralizable string can be marked as 'translated' while the variants are still marked as 'needs_review'. This can make the strings hard to find.
- Better comments for Interface Builder strings
    - For localizable strings inside Interface Builder files, Xcode exports very long comments that are actually old-style plist dictionaries containing mostly redundant or irrelevant information such as "ObjectID", "Class" or "title" (which just repeats the English UI string). `Xcloc Editor.app` filters out all this redundant stuff, so that localizers can focus on the hints that you wrote for them.
- When you ship `Xcloc Editor.app` next to .xcloc files, it will automatically show the user a picker between those .xcloc files.
- Supports undo and redo for all edits.
- Can be controlled and navigated completely via the keyboard.
- Shift-Return enters a newline, for the ChatGPT users. (But Option-Return is also supported)
- .xcloc file automatically saves on every edit so users don't have to manually save and no data will be lost.
- Window and column resizing is better than in Xcode
- Text-substitutions can be turned off.
    (E.g. smart-quotes, or "omw" -> "on my way". These always auto re-enable in Xcode.)
- Subtle '↩' marker so that localizers can easily distinguish between '\n' characters in the text vs line wrapping.

#### Drawbacks compared to Xcode's xcloc editor

- Can't edit "pluralizable format string"s (but that isn't necessary I think – see above)
- Format specifiers like "%@" don't get a special color background like they do in Xcode.
    - I don't think this is super helpful in Xcode especially since it also makes it impossible to edit the format specifier once it has the background which is a bit annoying. And for my project MMF, there are Javascript, Python and C format specifiers, which won't all get highlighted consistently by Xcode anyways. So I decided to just leave this feature out. [Open an issue](https://github.com/noah-nuebling/mf-xcloc-editor/issues/new) if you want this feature.

### Comparison with other xcloc editors

- The best native macOS xcloc editor that I came across is [LocaStudio](https://www.cunningo.com/locastudio/index.html). It's very good but has been abandoned and doesn't support the very useful 'state' feature. (Where strings can be marked as 'needs_review' or 'translated' – see above.)
- Comparison with online editors (like CrowdIn): 
  - These might be a better alternative for most projects. 
  - Reasons why I decided against them:
      - I personally didn't like the UI of most, which I perceived to be too complex. I thought Xcode's xcloc editor was much simpler without lacking important features.
      - I didn't wanna add a dependeny on an external service, which wants to integrate with your GitHub. 
      - I liked the idea of having all the data in my git history under my control and depending only on Apple's tooling. I also had a very buggy experience with CrowdIn's git-integration which put me off.
      - I also thought that my project Mac Mouse Fix wouldn't qualify for CrowdIn's free tier since it's monetized, but they talked to me via email and that was not true! 
          - -> CrowdIn DOES offer the free-tier to smaller indie apps even if they are monetized.
      - I also wasn't aware of the issues with Xcode's xcloc editor, which caused me to write this program, `Xcloc Editor.app`.
      - I looked at some CrowdIn projects and IIRC I didn't see much 'crowd' activity even on larger projects - Instead I saw a few people making larger contributions, which would make most perks of online-editors not-so-important.
  - Was this a good choice not to go with an online editor? 
    - I'm not sure, yet. Would I recommend it?  -If all the translatable files of your project are managed by Xcode (.xcstrings or .strings), then using `Xcloc Editor.app` might be easier to get started, lower the complexity and dependencies in your project, and provide a better experience for localizers than an online editor. But if your project contains other files, things get more complicated. For my project Mac Mouse Fix, I wrote Python scripts that call Apple's `xcstringstool` to host the translations for *all* the project files inside .xcstrings files, which can then be exported as .xcloc files. But it's probably less effort to use an online editor which already supports different file-types. 

### Comparison & thoughts on AI translation

I think that AI translation can be very good if it has the necessary context, but you have to provide that context. AI has less ability to access context compared to a human translator. For example, a translation AI typically wouldn't be able to easily look up how a term is translated in System Settings, or in Apple's documentation, or in other parts of your project. Also it won't be able to see the localization screenshots, or use your UI/website to experience how it functions and is laid out. All these things are easy for human translators using `Xcloc Editor.app`.

If you provide high-quality context to the AI, I think it will be able to match the quality of human translators.
I've translated the update notes for Mac Mouse Fix using AI (since it's impractical to do fast enough with volunteer translators). The quality is lacking. The most glaring issue is that the AI does not know how terms are translated inside other parts of the project, so will incorrectly refer to specific ui strings.

I don't know how hard it is in practice to provide good context to the AI.

<!--
- It's also nice to have all users of the app be able to spot issues and submit fixes relatively easily. (Although I'm not sure how many people will actually do that) 
- I decided against AI translation, when I started working on the new localization system for Mac Mouse Fix in 2024, partly because I thought building the system would be way easier and I could just use Xcode's built-in tooling for everything, but also because I thought the quality of the translations would not be as good. 
- Despite these pros, if I did this again, I may have went with AI translation. I probably would have had the AI translate everything from English to German (a language that I speak) and then tweak the instructions and localizer hints until the AI produces the same German translations that I would have written. I think once the AI can translate very well into one language, it can probably translate into other languages at the same quality.  I haven't tested  of these ideas, though.
-->

### Other Caveats

I made this specifically for my app Mac Mouse Fix. I didn't do extensive testing with other project's .xcloc files.

If you encounter any problems, feel free to [open an issue](https://github.com/noah-nuebling/mf-xcloc-editor/issues/new) or a pull request!

### Building

Just open in Xcode and hit the play button. 

If there are problems, please [open an issue](https://github.com/noah-nuebling/mf-xcloc-editor/issues/new). 

### Shipping

You can download the latest release [here](https://github.com/noah-nuebling/mf-xcloc-editor/releases/latest) and send it to your localizers alongside your .xcloc files.
