# termstrap

Reproducible, opinionated terminal setup shared between macOS (Apple Silicon
and Intel) and Debian/Ubuntu Linux machines: one Zsh and tmux configuration,
one tool set, installed the same way everywhere.

It is opinionated on purpose. Out of the box you get [micro](https://micro-editor.github.io)
as the terminal editor, a minimal green/blue Zsh prompt, `eza`/`bat` aliases in
place of `ls`/`cat`, and (on macOS `full`) iTerm2 with JetBrains Mono Nerd
Font. Everything personal or machine-specific goes in local override files
(`~/.zshrc.local`, `~/.tmux.conf.local`) that updates never touch — see
[Local overrides](#local-overrides).

Two profiles on both platforms:

- `core`: essential terminal tools. Suitable for restricted or automation
  ("agent") accounts; there is no separate agent profile.
- `full`: everything in `core`, plus `btop`, `duf`, `shellcheck`, `dust`
  (and on macOS iTerm2 and a Nerd Font), and optional Conda enablement.

## What it configures

- Fast Zsh prompt, history, completion, autosuggestions, and syntax highlighting
- Portable Homebrew shell initialization for Apple Silicon, Intel macOS, and
  Linuxbrew when it is already installed
- Shared tmux configuration with TPM-managed session persistence, clipboard,
  CPU/RAM status, text extraction, and URL/file opening
- Micro as the terminal and Git editor
- Homebrew-managed command-line tools (macOS); apt- and Cargo-managed
  command-line tools (Linux)
- Delta for readable Git output
- Lazy-loaded NVM with Node.js 22 (macOS)
- Lazy-loaded Conda when a Conda installation exists (`full` only)
- Optional OrbStack shell integration when installed (macOS)

It deliberately does **not** copy or configure Git identity, SSH keys, tokens,
cloud credentials, shell history, iTerm2 settings, or Conda environments.
Credentials and Git identity stay per-account and are never managed by this
repository.

## Get the repository

```zsh
git clone https://github.com/gunnarkw/termstrap.git
cd termstrap
```

Fork it first if you want to track your own tool choices — see
[Customizing](#customizing).

## Install on a Mac

Install Apple's command-line tools first if needed:

```zsh
xcode-select --install
```

Then run one profile from the repository directory:

```zsh
./install-macos.sh full
```

For a restricted or agent account:

```zsh
./install-macos.sh core
```

The installer:

1. Installs Homebrew if it is missing.
2. Installs the selected Brew bundle.
3. Creates timestamped backups of existing `.zshrc`, `.zprofile`, and
   `.tmux.conf` files.
4. Links the managed configuration into the account's home directory.
5. Installs NVM and Node.js 22 if needed.
6. Applies non-identifying Git defaults.
7. Installs TPM and the declared tmux plugins.
8. Runs validation.

Restart the terminal after installation, or run:

```zsh
exec zsh -l
```

### Verify on a Mac

```zsh
./verify-macos.sh full
```

Use `core` instead for a core-profile account.

## Install on Linux

Supported: Debian/Ubuntu and derivatives that use `apt`. The installer refuses
to run on other systems.

```zsh
./install-linux.sh [core|full] [all|system|user]
```

The profile defaults to `core` and the mode defaults to `all`, so
`./install-linux.sh core` is the same as `./install-linux.sh core all`, and
plain `./install-linux.sh` works too.

The three modes:

- `system`: installs the apt packages for the selected profile. Uses `sudo`
  when not already root. Writes nothing to the invoking user's home directory
  and does not touch login shells, Rust, or dotfile links.
- `user`: everything that belongs to the current account, with no `sudo` at
  all. Verifies the system packages are present (and tells you to ask an
  administrator to run `system` mode if they are not), creates
  `~/.local/bin` with `bat`/`fd` compatibility links, installs Cargo tools
  (`eza`, `git-delta`, plus `dust` for `full`) — bootstrapping a minimal
  per-user Rust toolchain via rustup only if Cargo is needed and absent —
  links the Zsh and tmux configuration, and installs TPM plugins. If the login
  shell is not Zsh, it prints the command to change it but does not run it.
- `all`: `system` followed by `user`. Right for a single interactive account
  that has `sudo`.

Every mode is idempotent: rerunning reconciles packages and reuses existing
managed links without creating new backups.

### Single account with sudo

Clone the repository into the account, enter it, and run:

```zsh
./install-linux.sh core
```

Use `full` instead on a workstation that should get the extra tools.

### Separated administrator and agent accounts

A common pattern for machines that run automation: an administrator account
(here `admin`) with sudo, and a restricted account (here `agent`) that
deliberately has **no sudo access**. Package installation and per-user setup
are split between the two. Each account needs its own clone of this repository
(the `~/.zshrc` symlink points into the clone).

1. As `admin`, install the system packages:

   ```zsh
   ./install-linux.sh core system
   ```

2. As `agent`, from that account's clone of this repository:

   ```zsh
   ./install-linux.sh core user
   ```

3. As `admin`, set the agent's login shell (a passwordless account cannot run
   `chsh` itself):

   ```zsh
   sudo usermod -s /usr/bin/zsh agent
   ```

4. As `agent`, verify:

   ```zsh
   ./verify-linux.sh core
   ```

### bat and fd compatibility links

Debian and Ubuntu install the `bat` package as `batcat` and `fd-find` as
`fdfind` because of historical name clashes. `user` mode creates
`~/.local/bin/bat` and `~/.local/bin/fd` symlinks to the real binaries, but
only when the canonical command name is not already available.

### Verify on Linux

```zsh
./verify-linux.sh core
```

Use `full` for the full profile. Verification never needs privileges. A login
shell that is not Zsh is reported as a warning, not a failure, because only an
administrator may be able to change it.

## tmux

The shared configuration works unchanged on macOS and Linux. It uses prefix
`Ctrl-b`, starts window and pane numbering at 1, keeps 50,000 lines of
scrollback, opens splits in the current directory, and supports pane navigation
with Alt plus the arrow keys. Mouse mode is enabled for pane selection,
resizing, and scrolling. Hold the terminal's bypass modifier when native text
selection is needed (typically Shift on Linux terminals or Option in iTerm2,
depending on terminal settings).

TPM installs these plugins:

- `tmux-resurrect` and `tmux-continuum` for manual and automatic session saves
- `tmux-yank` for platform-aware clipboard integration
- `tmux-cpu` for CPU and RAM status
- `extrakto` for fuzzy extraction of paths, URLs, and visible text
- `tmux-open` for opening selected paths and URLs

Installers reload the managed configuration into an existing tmux server before
asking TPM to install plugins. If no server exists, they create and remove a
short-lived installation session. Verification checks each declared plugin, not
only TPM itself.

`tmux-sensible` is deliberately omitted because the shared configuration sets
the desired behavior explicitly. Homebrew and Linuxbrew command directories are
listed explicitly in both `.zprofile` and `.zshrc`, so their commands remain
available in login shells and tmux panes. The shared configuration deliberately
does not evaluate `brew shellenv`: that command imports package-manager-owned
completion directories which Zsh correctly rejects on multi-user machines.

Useful bindings:

- `Ctrl-b |` and `Ctrl-b -`: horizontal and vertical splits
- `Alt-Arrow`: move between panes
- `Ctrl-b PageUp`: enter copy mode and scroll up
- In Vi copy mode, `v` starts selection, `y` copies and exits, and `Y` copies
  the current line; `set-clipboard on` sends copied text through OSC 52 when
  supported by the local terminal. These portable bindings load after TPM so
  `tmux-yank` cannot replace them with platform-local commands such as `xclip`.
- `Ctrl-b r`: reload the configuration
- `Ctrl-b Ctrl-s` and `Ctrl-b Ctrl-r`: save and restore sessions
- `Ctrl-b Tab`: extract visible text with `extrakto`

Run tmux directly for shell sessions. Other terminal multiplexers and agent
session managers should run standalone rather than nested inside tmux.

## Local overrides

Machine-specific and personal configuration belongs in files the repository
never manages:

- `~/.zshrc.local` — sourced near the end of `.zshrc` (before the highlighting
  plugins, so added widgets and bindings are highlighted). Prompt tweaks,
  extra aliases, private environment variables, work-specific tooling.
- `~/.tmux.conf.local` — sourced at the end of `.tmux.conf`.

Both are optional. Because updates only ever replace the managed symlinks,
anything in these files survives every update and reinstall.

## Account-specific Git identity

Set this only on an account that should make commits. Do not add these values
to the repository:

```zsh
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

Leave restricted or agent accounts without a personal identity unless they
genuinely need to create commits. Use a dedicated bot identity if they do.

## Update

After pulling repository changes, rerun the same installer (and mode) you used
before. Existing managed links are reused, packages are reconciled, and backups
are created only when an unmanaged file would be replaced.

## Roll back shell files

When an installer replaces an unmanaged shell file, it first copies it to:

```text
~/.dotfiles-backups/YYYYMMDD-HHMMSS/
```

To roll back, remove the managed symlinks (for example `~/.zshrc`) and copy the
desired backup files back into the home directory.

## Customizing

For personal additions, prefer `~/.zshrc.local` and `~/.tmux.conf.local` —
no fork needed, and updates stay a plain `git pull`.

Fork the repository when you want different managed defaults:

- Tool set: edit `Brewfile.core` / `Brewfile.full` (macOS) and the package
  arrays at the top of `install-linux.sh`.
- Pinned versions: the Node.js major version and the nvm installer version
  live near the bottom of `install-macos.sh`.
- Shell and tmux defaults: `zsh/.zshrc`, `zsh/.zprofile`, `tmux/.tmux.conf`.

If you change the managed tool set, mirror the change in `verify-macos.sh` /
`verify-linux.sh` so verification keeps telling the truth. CI runs `bash -n`,
ShellCheck, and Zsh syntax checks on every push.

## License

[MIT](LICENSE)
