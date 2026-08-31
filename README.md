# dotfiles

macOS + Linux machine configuration, managed with [chezmoi](https://chezmoi.io).
Secrets are [age](https://age-encryption.org)-encrypted in-repo.

> **This repo must stay private.** Even with secrets encrypted, `.devrc` contains
> an internal host and work repository paths.

## Bootstrap a new machine

1. **Restore the age key first.** It is in 1Password (item: *chezmoi age key*).
   Without it, `apply` aborts on the encrypted files.

   ```sh
   mkdir -p ~/.config/chezmoi
   op read "op://Private/chezmoi age key/notesPlain" > ~/.config/chezmoi/key.txt   # or paste it
   chmod 600 ~/.config/chezmoi/key.txt
   ```

2. **Run chezmoi.** It installs itself, clones this repo, and applies everything.

   ```sh
   sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply \
     --source="$HOME/Documents/Personal/repositories/dotfiles" neriat/dotfiles
   ```

   You are prompted once for **name**, **email**, and **profile**
   (`work` or `personal`). The answers are stored in `~/.config/chezmoi/chezmoi.toml`
   and never asked again.

That single command installs Homebrew, installs everything in the Brewfiles,
writes every config file, and applies the macOS system defaults.

## Layout

```
.chezmoiroot          -> "home"; keeps the repo root free for these files
Brewfile              cross-platform packages (macOS + Linux)
Brewfile.darwin       macOS-only formulae, all casks, Mac App Store apps
home/                 the chezmoi source directory
  .chezmoi.toml.tmpl    init prompts; sets sourceDir + age config
  .chezmoiignore        OS matrix and the .blockaidrc profile gate
  .chezmoiexternal.toml oh-my-zsh, powerlevel10k, 6 zsh plugins (weekly refresh)
  .chezmoiscripts/      homebrew install, brew bundle, macOS defaults
  dot_zshrc             thin loader; real config is in dot_config/zsh/
  dot_config/zsh/       00-path, 10-omz, 30-aliases, 50-keybindings
  private_Library/      darwin-only symlinks into ~/.config (VS Code, Cursor)
```

Source-file naming: `dot_` → leading `.`, `private_` → mode 0600/0700,
`encrypted_` → age blob, `symlink_` → symlink, `.tmpl` → templated.

## Daily use

```sh
chezmoi add ~/.config/foo/bar     # start tracking a file
chezmoi add --encrypt ~/.secret   # ...as an encrypted file
chezmoi edit ~/.zshrc             # edit the source, not the target
chezmoi diff                      # what would apply change?
chezmoi apply                     # write changes to $HOME
chezmoi cd                        # shell into the source dir to commit/push
chezmoi --refresh-externals apply # force-refresh oh-my-zsh & plugins
```

## Apps whose state cannot be reproduced

Four apps install cleanly but carry state the repo cannot carry for you.

**Cloudflare WARP.** Every setting `warp-cli settings` reports is marked
`(network policy)` or `(override)` -- it is pushed from the Cloudflare Zero Trust
dashboard, not stored locally. `/Library/Application Support/Cloudflare` is
root-owned device registration specific to one machine. The only reproducible
piece is enrolment, which script 28 runs for you:

```sh
warp-cli teams-enroll blockaid     # then finish sign-in in the browser
```

The script exits early if the device is already registered, so it never disturbs
a working VPN.

**Okta Verify.** Enrolment is a device-bound key; there is nothing exportable.
Re-enrol by hand from your Okta dashboard on a new machine.

**Postman.** Deliberately untracked. `Postman_Config` is 359 bytes of
server-driven feature flags and the rest of the 596 MB is Electron cache -- no
tokens, no user settings. Collections and environments live in your Postman
account and sync on sign-in.

**AltTab (paid tier).** `com.lwouis.alt-tab-macos.license` stores only
`customerEmail`, a validation timestamp and a cached `lastValidationResult` --
**no licence key exists locally**, and there is no Keychain item either.
Validation is server-side against the email. The domain is tracked
age-encrypted so a new machine knows which email to enter; activation still
happens online. The timestamps are stripped at capture so the encrypted blob
does not churn.

## Rust

`rustup` is installed from <https://sh.rustup.rs> by
`run_onchange_after_25-rust.sh.tmpl`, **not** Homebrew -- brew's `rust` formula and
rustup-managed toolchains both want to own `~/.cargo/bin`. The installer runs with
`--no-modify-path` because `~/.zshenv` (chezmoi-managed) already sources
`~/.cargo/env`.

Toolchains and cargo-installed binaries live in the repo-root **`Cargofile`**, in
the same spirit as the Brewfiles:

```
toolchain stable
crate mdbook
crate avm --git https://github.com/coral-xyz/anchor
```

The script consults `cargo install --list` before installing anything, so
re-applying never rebuilds an existing binary, and uses `cargo-binstall` for
prebuilt artifacts where one exists.

Two things deliberately absent: the pinned `1.81.0` / `1.86.0` / `1.90.0`
toolchains (projects pull those in via `rust-toolchain.toml`) and the `solana`
toolchain (registered by Solana tooling with `rustup toolchain link`, not
installable from a manifest). `clodashboard` is also skipped -- it installs from a
local checkout path that won't exist on a new machine.

## Apps installed by hand

`brew bundle` runs with `HOMEBREW_CASK_OPTS="--adopt"` (set in
`run_onchange_after_20-brew-bundle.sh.tmpl`). Most GUI apps here were originally
dragged from a `.dmg`, so Homebrew did not own them and would otherwise abort with
*"It seems there is already an App at ..."*. `--adopt` takes over the existing bundle
in place -- nothing is re-downloaded and nothing is deleted.

Adoption is refused when the on-disk artifact differs from the cask's version. Fix
those one at a time (check the version, then `brew install --cask --force <name>` if
replacing it is genuinely what you want) rather than adding `--force` globally.

The Claude Code CLI is deliberately *not* a Homebrew package -- it is installed by
`run_onchange_after_30-claude-code.sh` via `curl -fsSL https://claude.ai/install.sh | bash`,
the method Anthropic documents. That script only installs when `claude` is missing,
because Claude Code updates itself.

## macOS settings

Three layers, in increasing order of bluntness:

| Layer | Where | Use for |
|---|---|---|
| Curated `defaults write` | `run_onchange_after_40-macos-defaults.sh.tmpl` | System toggles you want stated explicitly and readably |
| Whole-domain import | `~/.config/macos-defaults/*.plist` + `...35-import-macos-prefs...` | Third-party apps whose keys you don't know, and structures too complex to hand-write (keyboard shortcuts, menu-bar layout) |
| Nothing | — | Mail, Safari, Passwords, FindMy, display arrangements: credential-bearing or machine-bound |

Preferences cannot be tracked as plain files -- `cfprefsd` caches each domain in
memory and overwrites direct writes -- so the plists are applied with
`defaults import`. Script 35 runs **before** script 40 deliberately:
`defaults import` merges its plist into the domain, overwriting any key it
carries, so the curated writes must come after to win on keys both touch
(`com.apple.dock`). Merging also means keys stripped at capture stay untouched on
the machine.

Tracked domains:

```
com.apple.symbolichotkeys       custom keyboard shortcuts
com.apple.dock                  dock layout (recent-apps/mod-count stripped)
com.apple.controlcenter         menu bar layout
com.knollsoft.Rectangle         org.p0deje.Maccy
com.lwouis.alt-tab-macos        art.ginzburg.MiddleClick
com.vorssaint.utils
cc.ffitch.shottr                encrypted -- holds a licence key
fyi.lunar.Lunar                 encrypted -- holds a licence key
pro.betterdisplay.BetterDisplay encrypted -- holds a licence key
```

### The `macos-prefs` helper

`~/.local/bin/macos-prefs` (tracked at `home/dot_local/bin/`) does two jobs.

**Re-capture** after changing settings in an app's UI:

```sh
macos-prefs capture                 # refresh every tracked domain
macos-prefs capture com.foo.bar     # start tracking a new one
chezmoi re-add ~/.config/macos-defaults
```

It strips volatile keys (`NSWindow*`, `NSStatusItem*`, `recent-apps`, `mod-count`)
so captures don't churn.

**Discover** which key a System Settings toggle writes -- macOS offers no way to
ask this:

```sh
macos-prefs snap                    # snapshot all ~600 domains
# ...flip the setting in System Settings...
macos-prefs diff                    # prints the exact `defaults write` command
```

Paste the result into script 40. (This is what `plistwatch` does; it isn't in
Homebrew, so it's reimplemented here.)

### Permissions are not reproducible

TCC privacy grants -- Accessibility, Screen Recording, Input Monitoring -- are
SIP-protected and deliberately cannot be exported. On a new Mac, re-grant them by
hand or these apps will silently do nothing:

- **Accessibility:** Rectangle, Amethyst, AltTab, Maccy, MiddleClick, Vorssaint, Parsec
- **Screen Recording:** Shottr, AltTab
- **Input Monitoring:** MiddleClick, Karabiner-Elements
- **Full Disk Access:** any terminal you run `chezmoi apply` from

## Shell load order

`~/.zshrc` is deliberately thin. Order matters:

1. **p10k instant prompt** — must be first; nothing may write to stdout above it.
2. **`~/.config/zsh/*.zsh`** — `00-path.zsh` assembles `fpath`, then `10-omz.zsh`
   sources oh-my-zsh, which runs the session's **single** `compinit`.
   Add every new `fpath` entry to `00-path.zsh`, never a second `compinit`.
3. **`~/.devrc`, `~/.blockaidrc`** — under `set -a`, so their bare `NAME=value`
   assignments export. These must load *after* step 2: `.blockaidrc` calls
   `compdef`, which does not exist until `compinit` has run.
4. **`~/.p10k.zsh`** — prompt theme.

`~/.config/zsh/99-local.zsh` is gitignored — use it for per-machine tweaks.

## Machine profiles

`profile` is asked once at init. **Normal is the base set that applies to every
machine; work is purely additive** -- nothing is subtracted on a personal machine,
work simply adds more.

Two things are work-gated:

| Gated | Contains |
|---|---|
| `.blockaidrc` | registry credentials, `GEMINI_API_KEY`, AWS SSO helpers |
| `Brewfile.work` | Cloudflare WARP, Okta Verify, HP Easy Scan |

Plus `run_onchange_after_28-warp-enroll.sh.tmpl`, which renders to nothing at all
off a work machine.

Everything else -- including all the personal apps in `Brewfile.darwin` -- applies
everywhere. OS splitting is separate and automatic via `.chezmoiignore`:
`Library/**`, cmux, karabiner, zellij and macos-defaults are skipped off macOS.

## Deliberately not tracked

| Thing | Why |
|---|---|
| `~/.ssh/known_hosts` | machine-accumulated; constant diff noise |
| `~/.config/raycast` | 79 MB of extension bundles |
| Raycast shortcuts/aliases | see below -- not extractable |
| `~/.config/gcloud` | 89 MB of cached credentials and components |
| `~/.claude/{projects,sessions,history.jsonl,cache,plugins}` | volatile session state |
| nvim, fish, sketchybar, aerospace configs | dropped on purpose |
| pyenv, pipx, nvm, gcloud | dropped; `fnm` is the Node manager now |

### Raycast shortcuts

Raycast's aliases, hotkeys, quicklinks and snippets are **not** recoverable from this
repo, and three routes were checked:

- Its SQLite databases are SQLCipher-encrypted (`main.db` does not start with
  `SQLite format 3`), so `sqlite3` cannot read them.
- Cloud Sync needs Raycast Pro (`subscriptions_active = 0` here).
- `com.raycast.macos.plist` holds only window geometry and migration flags -- no
  shortcuts -- and the 426 MB support directory also contains clipboard history, so
  neither is safe or useful to track.

The only export is a Raycast *command*, not a Settings page: open Raycast and search
**"Export Settings & Data"**. It asks for an encryption password and a save location,
so it cannot be scripted. Drop the resulting `.rayconfig` in this repo to version it.

`aerospace` is still installed on this Mac but intentionally absent from
`Brewfile.darwin`, so a new machine will not get it.

`powershell` exists here as both a formula and a cask; only the cask is tracked.

## Editor settings

VS Code and Cursor read from `~/Library/Application Support/<App>/User/` on macOS
and `~/.config/<App>/User/` on Linux. The real files live in `~/.config`, and macOS
gets symlinks. If either app ever replaces a settings file instead of writing
through the symlink, `chezmoi apply` restores the link.

## Pushing to this repo (two GitHub accounts)

This machine is signed in to GitHub as both `neriat` (personal, owns this repo)
and `neria-blockaid` (work). Two things would otherwise send pushes to the wrong
identity:

- `~/.gitconfig` rewrites `https://github.com/` -> `git@github.com:`, and the
  SSH key here belongs to the **work** account.
- `gh auth`'s active account is global, so switching it would disturb work repos.

Both are handled without touching either:

```sh
# remote carries the username, so the insteadOf rewrite does not match it
git remote set-url origin https://neriat@github.com/neriat/dotfiles.git

# repo-local credential helper pins this repo to neriat, whatever gh's active
# account is. The empty first value resets the inherited helper chain.
git config --local --replace-all credential.https://github.com.helper ""
git config --local --add credential.https://github.com.helper \
  '!f() { echo username=neriat; echo "password=$(gh auth token --user neriat)"; }; f'
```

This lives in `.git/config`, which is not tracked, so re-apply it after a fresh
clone on another machine.

## Rotating the age key

The key is the single point of failure for this repo. To rotate:

```sh
age-keygen -o ~/.config/chezmoi/key.new
chezmoi cat ~/.blockaidrc > /tmp/plain          # decrypt with the OLD key
# update age.recipient in .chezmoi.toml.tmpl and ~/.config/chezmoi/chezmoi.toml
mv ~/.config/chezmoi/key.new ~/.config/chezmoi/key.txt
chezmoi add --encrypt ~/.blockaidrc ~/.ssh/id_ed25519 ~/.ssh/id_ed25519_openclaw ~/.ssh/notebook.pem
shred -u /tmp/plain
```

Then update the 1Password item and force-push the rewritten blobs.
