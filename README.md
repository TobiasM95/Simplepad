# Simplepad

Simplepad is a deliberately small, native macOS plain-text editor. It edits UTF-8 text only—there is no rich text, Markdown rendering, document formatting, account, cloud service, or browser runtime.

## What it does

- Opens multiple files in a single window with lightweight tabs.
- Creates an untitled tab with **⌘T** and opens text files with **⌘O**.
- Stores every open tab continuously, including tabs that have never been saved.
- Restores the same buffers, tab order, selected tab, zoom, and wrapping after quitting or an unexpected termination.
- Detects files changed or removed by another application without silently replacing buffered work.
- Reads strict UTF-8 (with or without a UTF-8 BOM) and always writes UTF-8 without a BOM.
- Uses a native, plain `NSTextView`; pasted content is reduced to plain text.

Simplepad targets macOS 15 or later and is tested by CI on macOS 15. macOS 26 Tahoe is supported.

## Install a GitHub release

1. Download `Simplepad-<version>-macOS-universal.zip` and its `.sha256` file from the repository’s latest GitHub Release.
2. Optionally verify the download in Terminal:

   ```sh
   shasum -a 256 -c Simplepad-<version>-macOS-universal.zip.sha256
   ```

3. Unzip the archive and move **Simplepad.app** to `/Applications`.
4. Because personal-project releases are intentionally unsigned and not notarized, Control-click **Simplepad.app**, choose **Open**, then confirm **Open**. A normal double-click may be blocked by Gatekeeper on first launch.

The release is universal and contains both Apple Silicon and Intel code.

## Keyboard shortcuts

| Action | Shortcut |
| --- | --- |
| New tab | ⌘T |
| Open | ⌘O |
| Save | ⌘S |
| Save As | ⇧⌘S |
| Close tab | ⌘W |
| Find | ⌘F |
| Zoom in / out | ⌘+ / ⌘- |
| Actual size | ⌘0 |

Quitting Simplepad does not ask you to save: all open buffers return next time. Deliberately closing a dirty or untitled tab does ask for confirmation because that action permanently removes its persistent buffer.

## Persistence and file conflicts

Session data lives in `~/Library/Application Support/Simplepad`. Each tab has a separate UTF-8 buffer file, while tab metadata is stored in an atomically replaced manifest with a backup. If both manifests are damaged, intact buffer files are recovered as tabs instead of being deleted.

For disk-backed tabs, the buffer is authoritative until you save or reload. Simplepad checks the file when it becomes active and before saving. A clean tab reloads an external change; a dirty tab keeps its buffer and offers **Reload**, **Save Anyway**, or **Save As**.

## Development

Requirements:

- macOS 15 or later
- Xcode 16.4 or a compatible newer Xcode

Open `Simplepad.xcodeproj` and run the shared **Simplepad** scheme, or use the command line:

```sh
xcodebuild test \
  -project Simplepad.xcodeproj \
  -scheme Simplepad \
  -destination 'platform=macOS'
```

Build the same unsigned universal package produced by releases:

```sh
bash scripts/package-release.sh
```

Artifacts are written to `dist/`. The project has no third-party runtime or build dependencies.

## CI and releases

CI builds, runs unit and UI tests, and packages a universal app for every pull request and push to `main`. GitHub Actions dependencies are pinned to immutable commits and monitored by Dependabot.

Releases use [Conventional Commits](https://www.conventionalcommits.org/):

- `fix:` produces a patch candidate.
- `feat:` produces a minor candidate.
- `feat!:` (or a `BREAKING CHANGE` footer) produces a major candidate.

Release Please keeps a release pull request up to date. Merging that pull request creates the version tag and GitHub Release; the release workflow then tests the tagged commit, builds the unsigned universal app, and attaches its ZIP and SHA-256 checksum.

One repository setting may need to be enabled once: under **Settings → Actions → General → Workflow permissions**, allow GitHub Actions to create pull requests. No Apple Developer membership, certificate, secret, or self-hosted runner is required.

## Project layout

- `Simplepad/` — application, editor, file access, and session storage.
- `SimplepadTests/` — encoding, persistence, recovery, fingerprint, and model tests.
- `SimplepadUITests/` — menu, tab shortcut, and relaunch restoration smoke tests.
- `scripts/package-release.sh` — reproducible unsigned universal packaging.
