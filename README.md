# iExtendio

An API extension for Legacy iOS! WIP.

> **WARNING:** This is more of a proof-of-concept. This API extension is very unstable!

## How it works

iOS 7 apps reference symbols and frameworks that don't exist on iOS 6. iExtendio
layers those back in so the app launches on iOS 6:

- **`GameController.dylib`** — a stub `GameController.framework` replacement
  (`GameController.x`), since iOS 6 has no GameController framework.
- **`empty.dylib`** — a tiny placeholder library whose install name is
  `/usr/local/lib/empty.dylib`. It only exists to be reexported at link time.
- **`ReExtendioDylib.dylib`** — defines the symbols iOS 6's libSystem is missing
  (`__sincos_stret`, `__exp10`) and reexports `empty.dylib`. After building, the
  reexport is repointed to `/usr/lib/libSystem.B.dylib` so the stubs get layered
  on top of the real system library at runtime.

## Compatibility list

| App | Status |
| --- | --- |
| RedBall 4 | Gets ingame and **doesn't crash** (‼️). GameController part still WIP, but it works! 👍 |
| Where's my Perry | Not thoroughly tested, but gets ingame as of the latest commit. |
| PPAP | Gets ingame, but crashes with `KERN_INVALID_ADDRESS` at `0x00000000` once your bullet reaches the top. |

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
# GameController.dylib
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

1. Download the latest dylibs from **Releases**, or compile them yourself (above).
2. Extract the `.ipa` in the same folder as the `.sh` scripts.
3. Put the dylibs in the root folder where iExtendio resides.
4. Patch `ReExtendioDylib.dylib` to reexport from `libSystem.B` with
   `PatchDylib.sh` (this already happens if you followed the build steps).
5. Patch your IPA with `ExtendioLegacyPatch.sh`, supplying the extracted app name.

## Continuous builds

`.github/workflows/build.yml` builds all dylibs on Ubuntu using the Theos Linux
toolchain on every push/PR, uploads them as build artifacts, and attaches them to
a GitHub Release when you push a `v*` tag (e.g. `git tag v0.0.1 && git push --tags`).
