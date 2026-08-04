# GitHub Actions Releases — Discussion

## The Core Problem: V8

GitHub Actions provides free Linux, macOS, and Windows runners for public repos.
The hard part is the **V8 dependency**, which must be solved before writing any workflow files.

`install-deps.sh` handles Linux (apt `libnode-dev`) and macOS (brew) reasonably.
Windows is the blocker — there is no `libnode-dev` equivalent, and building V8 from
source in CI takes 30–60 minutes, requires enormous RAM, and is notoriously fragile.

## Options (ranked by effort)

### Option 1 — Java/GraalVM version with GraalVM Native Image (lowest friction)

GraalVM Native Image compiles Java to native executables per platform. You already have
a Java version using GraalVM. GitHub Actions has good support via `graalvm/setup-graalvm`.
One matrix, three platforms, native binaries on all three. Likely the path of least resistance.

Tradeoffs:
- Binary size is larger than a hand-compiled C++ binary
- Startup slightly slower than bare C++ (still fast)
- Depends on GraalVM polyglot working correctly via native-image

### Option 2 — Swap V8 for QuickJS in the C++ version

QuickJS is a single-file C library, trivially cross-compiled, no native deps, tiny binaries.
Cleanest C++ path to all three platforms, but requires rewriting `v8_host.cpp`.

Tradeoffs:
- Real porting work on the V8 integration layer
- QuickJS is less battle-tested than V8 for edge cases
- Result is a small, fast, zero-dep native binary on all platforms

### Option 3 — C++ with V8 as-is on all platforms (highest friction)

- Linux: works fine with `libnode-dev`
- macOS: works with brew, but header paths differ and need adjustment
- Windows: needs either vendored prebuilt V8 `.lib`/`.dll` files, or significant
  effort wiring up MSVC build tools — painful and slow in CI

### Option 4 — C++ with V8 DLL bundled in an NSIS Windows installer (chosen approach)

Build the C++ binary on Windows linking against a V8/Node DLL, then ship it as a
standard NSIS installer that bundles the DLL alongside `jamcrest.exe`.

This is the conventional Windows distribution pattern and gives users a clean install
experience (double-click installer, optionally adds jamcrest to %PATH%).

**Getting the V8 DLL — options:**

- **Build Node.js with `--shared`** on the Windows CI runner. Produces `node.dll`,
  consistent with the Linux `libnode` approach. Slow first run (30–60 min) but
  `actions/cache` keyed on the Node version makes subsequent runs fast.

- **Deno's prebuilt V8** (`rusty_v8` project) maintains prebuilt V8 static libs for
  Linux, macOS, and Windows. Static linking means no DLL to bundle, but the binary
  will be larger (~50 MB).

- **Electron's prebuilt V8** — Electron ships V8 headers + libs for all platforms.
  Unconventional without Electron itself, but technically usable.

- **Official V8 prebuilts** — the V8 project does not publish official prebuilt DLLs,
  so this is not a clean option.

**Recommended path for Windows:** Build Node.js `--shared` in CI with caching.
`v8_host.cpp` already targets the Node/V8 API so it is a consistent port of the
Linux version rather than a different integration.

**NSIS installer specifics:**
- GitHub Actions Windows runners have `makensis` available (or install via choco)
- Installer bundles `jamcrest.exe` + `node.dll` + any required MSVC CRT redistributables
- Optionally writes `jamcrest` to `%PATH%` at install time for use from cmd/PowerShell
- NSIS scripts are plain text and version-controllable — no GUI tooling required

## What the GitHub Actions workflow needs

1. **Trigger**: `on: push: tags: ['v*']` — fires when you push a tag like `v0.1.4`
2. **Matrix**: `os: [ubuntu-latest, macos-latest, windows-latest]`
3. **Build step per platform**: install deps, compile, strip binary
4. **Windows extra step**: run `makensis` to produce an `.exe` installer
5. **Create GitHub Release**: using `gh release create` or `softprops/action-gh-release`
6. **Upload platform artifacts**:
   - `jamcrest-linux-amd64`
   - `jamcrest-macos-amd64`
   - `jamcrest-windows-installer.exe` (the NSIS installer)
7. **Versioning**: the `version` file and `pom.xml` should match the git tag

## Optional but worth considering

- **macOS code signing**: Without signing/notarization users see "unidentified developer".
  Requires Apple Developer ID ($99/year). Without it, users run:
  `xattr -d com.apple.quarantine jamcrest` — annoying but workable for a CLI tool.

- **aarch64 (Apple Silicon)**: `macos-latest` runners are now ARM. Add `macos-13`
  (Intel) if you want both architectures covered.

- **Checksums**: publish a `SHA256SUMS` file alongside binaries — standard practice.

## Recommendation

Stay with the **C++ + V8 approach** (Option 4) using the NSIS installer for Windows.
Build `node.dll` via `--shared` Node.js build in CI with aggressive caching.
For Linux and macOS, the existing `install-deps.sh` logic carries over directly.
This keeps one codebase and one consistent V8-backed runtime across all platforms.
