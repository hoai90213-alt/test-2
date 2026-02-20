# Ghi chu Build GitHub (PoC iOS Main Menu)

Thu muc nay la ban copy doc lap de day len GitHub.

## Tinh trang hien tai

- Da co workflow GitHub Actions build runtime `.tipa` day du (strict):
  - `.github/workflows/build-ios-tipa.yml`
- Da co workflow runtime probe + runtime `.tipa` (manual):
  - `.github/workflows/build-ios-runtime-tipa.yml`
- Da co iOS bootstrap app va script dong goi:
  - `ios/bootstrap/main.m`
  - `ios/bootstrap/Info.plist`
  - `ios/bootstrap/entitlements.trollstore.plist`
  - `ios/scripts/build_tipa.sh`
- Da co script build native runtime iOS probe:
  - `ios/scripts/build_runtime_probe.sh`
- Artifact dau ra tu workflow:
  - `artifacts/ZomdroidIOSRuntimePoC.tipa`
  - `artifacts/runtime-libs/*`
  - `artifacts/runtime-probe-build.log`

## Quan trong truoc khi build

Hien tai minh da clone san:

- `app/src/main/cpp/box64`
- `app/src/main/cpp/glfw`

Commit hien tai:

- `box64`: `4a725d5`
- `glfw`: `401b26c`

Luu y: 2 thu muc nay dang la repo Git long nhau (co `.git` rieng).

## Cach quan ly box64/glfw khi push repo cha

1. Chon mot trong hai cach:
- Cach A: giu dang submodule.
- Cach B: dua thanh source thuong trong repo chinh (xoa `.git` ben trong truoc khi commit repo cha).

Neu ban chon Cach B, co script:

```bash
bash ios/scripts/strip_nested_git.sh
```

2. Neu muon dung submodule thi setup lai:

```bash
git submodule add https://github.com/liamelui/zomdroid-box64 app/src/main/cpp/box64
git submodule add https://github.com/liamelui/zomdroid-glfw app/src/main/cpp/glfw
git submodule update --init --recursive
```

## Cac bien moi truong runtime da them

- `ZOMDROID_LIBRARY_DIR`
- `ZOMDROID_LINKER_LIB`
- `ZOMDROID_JVM_LIB`
- `ZOMDROID_VULKAN_LOADER_NAME`

## Muc tieu tiep theo

- Noi runtime game vao iOS shell de di tu bootstrap app sang moc Java entrypoint.
- Sau do tiep tuc huong den moc vao duoc main menu.

## Chay workflow tren GitHub

1. Build runtime `.tipa` day du (khuyen dung):
- Action: `build-ios-tipa`
- Workflow nay se:
  - build native runtime dylibs truoc,
  - thu 2 mode build runtime:
    - `ios-xcode` (mode chinh),
    - `amethyst-darwin` (fallback theo huong build cua Amethyst),
  - fail neu thieu `libbox64.dylib`, `libzomdroid.dylib`, `libzomdroidlinker.dylib`,
  - fail neu `.tipa` qua nho (chan artifact kieu "10KB").

2. Build runtime probe + runtime `.tipa` (manual debug):
- Action: `build-ios-runtime-tipa`
- Workflow nay se:
  - build native runtime probe (cmake iOS),
  - dong goi runtime libs vao app theo che do strict,
  - upload log + runtime libs + `.tipa` de debug.
