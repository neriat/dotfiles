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
| `~/.config/raycast` | 79 MB of extension bundles; use Raycast's own cloud sync |
| `~/.config/gcloud` | 89 MB of cached credentials and components |
| `~/.claude/{projects,sessions,history.jsonl,cache,plugins}` | volatile session state |
| nvim, fish, sketchybar, aerospace configs | dropped on purpose |
| pyenv, pipx, nvm, gcloud | dropped; `fnm` is the Node manager now |

`aerospace` is still installed on this Mac but intentionally absent from
`Brewfile.darwin`, so a new machine will not get it.

`powershell` exists here as both a formula and a cask; only the cask is tracked.

## Editor settings

VS Code and Cursor read from `~/Library/Application Support/<App>/User/` on macOS
and `~/.config/<App>/User/` on Linux. The real files live in `~/.config`, and macOS
gets symlinks. If either app ever replaces a settings file instead of writing
through the symlink, `chezmoi apply` restores the link.

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
