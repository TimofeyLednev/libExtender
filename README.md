# iExtendio

An API extension for Legacy iOS! WIP.

> **WARNING:** This is more of a proof-of-concept. This API extension is very unstable!

## How it works

iOS 7 apps reference symbols and frameworks that don't exist on iOS 6. iExtendio
layers those back in so the app launches on iOS 6:

- **`GameController.dylib`** — a stub `GameController.framework` replacement
  (`GameController.x`), since iOS 6 has no GameController framework.
- **`Photos.dylib`** — a stub `Photos.framework` replacement (`Photos.x`), since
  iOS 6 has no Photos framework (it arrived in iOS 8). Apps that link against it
  without calling into it would otherwise abort at dyld load time with
  `Library not loaded: .../Photos.framework/Photos`. The patch script only
  repoints it for apps that actually link Photos.
- **`empty.dylib`** — a tiny placeholder library whose install name is
  `/usr/local/lib/empty.dylib`. It only exists to be reexported at link time.
- **`ReExtendioDylib.dylib`** — defines the symbols iOS 6's libSystem is missing
  (`__sincos_stret`, `__exp10`) and reexports `empty.dylib`. After building, the
  reexport is repointed to `/usr/lib/libSystem.B.dylib` so the stubs get layered
  on top of the real system library at runtime.

## Compatibility list

| App | Status |
| --- | --- |
| RedBall 4 | **Fully playable** — fixed by the ABI-correct `__sincosf_stret` stub (‼️). |
| Where's my Perry | Not thoroughly tested, but gets ingame as of the latest commit. |
| PPAP | Gets ingame, but crashes with `KERN_INVALID_ADDRESS` at `0x00000000` once your bullet reaches the top. |
| Geometry Dash 2.11 | **Fully playable** - the game works completely and perfectly, and this is an iOS 8 game |
| Kiloblocks | **Fully playable** - the game works fully, and this is an iOS 8 game |
| Minecraft PE 1.1.5 | **WIP** — `Photos.dylib` stub fixes the dyld load-time crash (`Photos.framework` missing on iOS 6). Past the launch abort; further testing ongoing. |

## Building

You need [Theos](https://theos.dev). The project builds on **both macOS and Linux**.

### Linux toolchain setup (one time)

The old flow shipped a prebuilt `arm-apple-darwin11-install_name_tool` binary
because there was no working iOS toolchain on Linux. That's no longer needed —
Theos now has a full Linux iOS toolchain (clang + cctools).

```bash
export THEOS=~/theos
git clone --recursive https://github.com/theos/theos.git "$THEOS"

# Linux iOS toolchain (clang + install_name_tool, otool, ldid, ...)
mkdir -p "$THEOS/toolchain"
curl -fsSL \
  https://github.com/L1ghtmann/llvm-project/releases/latest/download/iOSToolchain-x86_64.tar.xz \
  | tar -xJf - -C "$THEOS/toolchain/"

# iOS SDKs
git clone --depth=1 https://github.com/theos/sdks.git /tmp/theos-sdks
cp -a /tmp/theos-sdks/iPhoneOS*.sdk "$THEOS/sdks/"

export PATH="$THEOS/toolchain/linux/iphone/bin:$PATH"
```

### Compile

```bash
# GameController.dylib + Photos.dylib
make

# empty.dylib + ReExtendioDylib.dylib
cd ReExtendioDylib && make && cd ..

# Repoint the reexport empty.dylib -> libSystem.B.dylib (works on Linux too)
cp ReExtendioDylib/.theos/obj/debug/ReExtendioDylib.dylib .
bash PatchDylib.sh ReExtendioDylib.dylib
```

Built dylibs land in `.theos/obj/debug/`. Prebuilt copies are also published by
the GitHub Actions workflow (see **Releases**, built on tag pushes).

## How to use

1. Download the latest `libExtender-linux.zip` from **Releases**, or compile the
   dylibs yourself (above).
2. Extract the `.ipa` in the same folder as the `.sh` scripts so you have a
   `Payload/` folder there.
3. On Linux, install a plist editor + zip once: `sudo apt-get install -y libplist-utils zip`.
4. Patch your app:

   ```bash
   ./ExtendioLegacyPatch.sh <AppName>
   ```

   This copies `ReExtendioDylib.dylib` plus the stub frameworks the app actually
   links (`GameController.dylib`, `Photos.dylib`) into a local
   `Payload/<AppName>.app/dylib/` folder, repoints the app executable to
   `@executable_path/dylib/...` (nothing system-wide is touched), bumps
   `MinimumOSVersion` to 6.0, and re-zips the result as `<AppName>.zip` (rename
   to `.ipa`). It auto-finds `install_name_tool` on `PATH`, in the bundled
   `tools/` folder, or under `$THEOS` — so no Theos install is required when
   using the release zip.

## Continuous builds

`.github/workflows/main.yml` builds all dylibs on Ubuntu using the Theos Linux
toolchain on every push/PR, uploads them as build artifacts, and attaches them to
a GitHub Release when you push a `v*` tag (e.g. `git tag v0.0.1 && git push --tags`).
