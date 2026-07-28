Drop Manrope's `.ttf` files here (Regular/Medium/SemiBold/Bold/ExtraBold — whichever
weights you use, per `ThemeFont` in `Sources/Theme.swift`).

Manrope is SIL Open Font License, free to use — get it from Google Fonts. Not included
in this skeleton since it needs to be downloaded from outside this environment's
allowed network domains.

`ManropeFonts.registerIfNeeded()` (in `Theme.swift`) registers whatever's in this
folder at launch via CoreText. If it's empty, `ThemeFont` falls back to the system
font automatically — nothing breaks, it just won't look like Manrope until you add
the files.
