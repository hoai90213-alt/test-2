## iOS 60% Strategy (Separate Folder Build)

This folder is a separate branch-style project focused on raising local iOS success odds.

### Why this path
- Previous flow imported Linux JVM (`libjvm.so` / renamed `.dylib`) and could crash.
- This build requires a valid iOS Mach-O JVM runtime folder.

### App workflow
1. `Import Game Folder`
2. `Import Deps Folder`
3. `Import Runtime Folder`
4. `Launch Runtime`

### Runtime workflow (GitHub Actions)
1. Run workflow: `build-ios-runtime-jvm`
2. Download artifact: `zomdroid-ios-runtime-import`
3. Extract `runtime-import.zip` to get folder `runtime/`
4. In app, use `Import Runtime Folder` and select this `runtime/`

### Required runtime format
- Runtime folder must contain one of:
  - `lib/server/libjvm.dylib`
  - `lib/libjvm.dylib`
- Binary must be Mach-O (iOS arm64), not Linux ELF.

### Paths inside app container
- `Documents/zomdroid/game`
- `Documents/zomdroid/deps`
- `Documents/zomdroid/runtime`
- `Documents/zomdroid/config`

### Notes
- If runtime is invalid, app now stops with clear error instead of crashing.
- This increases practical chance only when a real iOS runtime is supplied.
