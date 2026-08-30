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

## Vorssaint preferences

macOS preferences cannot be tracked as plain files -- `cfprefsd` caches each domain in
memory and overwrites direct writes. So the XML lives at
`~/.config/vorssaint/com.vorssaint.utils.plist` and
`run_onchange_after_50-vorssaint-prefs.sh.tmpl` applies it with `defaults import`.

After changing settings in the Vorssaint UI, re-capture them:

```sh
defaults export com.vorssaint.utils - > /tmp/v.plist
# strip the volatile NSStatusItem*/NSWindow* geometry keys, then:
cp /tmp/v.plist ~/.config/vorssaint/com.vorssaint.utils.plist
chezmoi re-add ~/.config/vorssaint/com.vorssaint.utils.plist
```

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

`profile` is asked once at init and gates exactly one thing: `.blockaidrc`
(work registry credentials, `GEMINI_API_KEY`, AWS SSO helpers) applies only when
`profile = "work"`. Everything else is personal and applies on every machine.

OS splitting is automatic via `.chezmoiignore`: `Library/**`, cmux, karabiner and
zellij are skipped off macOS.

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
