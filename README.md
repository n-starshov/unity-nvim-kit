# Neovim Unity C# Config (LazyVim)

Opinionated Neovim config for Unity + C# development on macOS and Linux.

## Platform support

- Supported: `macOS`, `Linux`
- Unsupported: `Windows` (not planned)

## What this config adds

- Roslyn LSP setup for C#
- Unity attach debug flow (`nvim-dap` + Unity debug adapter)
- Unity -> Neovim file opening via socket session scripts
- JetBrains CleanupCode integration for C# formatting
- LazyVim extras for `.NET` + `DAP`

## Requirements

- `nvim` in `PATH`
- `git`
- `.NET SDK` (`dotnet`)
- Unity project with exactly one IDE package: `com.unity.ide.visualstudio` or `com.unity.ide.rider`

Optional but recommended:

- `roslyn-language-server`
- JetBrains `jb` CLI (for `CleanupCode`)
- terminal app available in `PATH` (`ghostty`, `kitty`, `wezterm`, `alacritty`, `gnome-terminal`, `konsole`, `x-terminal-emulator`, or `xterm`)

## Install

1. Clone to `~/.config/nvim`.
2. Start `nvim` once to let Lazy install plugins.
3. Configure Unity External Tools with `External Script Editor = <path-to-your-nvim-config>/bin/unity-nvim-open` and `External Script Editor Args = $(File) $(Line) $(Column)`.
4. Start Neovim Unity session with `<path-to-your-nvim-config>/bin/unity-nvim-session`.

Detailed Unity setup also in [UNITY_SETUP.md](UNITY_SETUP.md).

## Key mappings (C# / Unity)

- `<leader>dU`: attach Unity editor (auto endpoint)
- `<leader>dE`: attach Unity editor (manual endpoint)
- `<leader>cC`: run JetBrains CleanupCode

## Environment variables

- `UNITY_NVIM_BIN`: explicit Neovim executable path
- `UNITY_NVIM_SOCKET`: socket path override
- `UNITY_NVIM_TERMINAL_CMD`: terminal launch command when no session exists
- `UNITY_NVIM_TERMINAL_APP`: macOS app name/path used with `open -na ... --args` fallback (default: `Terminal`)
- `UNITY_NVIM_EXTRA_PATH`: extra `PATH` entries for Roslyn/CleanupCode (`:` separated)
- `DOTNET_ROOT`: explicit .NET root if auto-detection fails
- `JB_CLEANUPCODE_BIN`: explicit `jb` executable

Linux examples:

```sh
export UNITY_NVIM_TERMINAL_CMD='ghostty -e'
# or
export UNITY_NVIM_TERMINAL_CMD='kitty -e'
```

macOS example:

```sh
export UNITY_NVIM_TERMINAL_CMD='open -na Terminal --args'
```

## If you already use LazyVim

Merge only Unity/C# layer instead of replacing whole config:

- `bin/unity-nvim-open`
- `bin/unity-nvim-session`
- `bin/csharp-cleanupcode`
- `lua/plugins/csharp.lua`
- `lua/plugins/csharp_format.lua`
- `lua/plugins/unity_dap.lua`

## Troubleshooting

- Unity opens nothing: ensure `unity-nvim-session` is running and socket path matches.
- LSP missing: verify `dotnet` and `roslyn-language-server` are in `PATH`.
- CleanupCode fails: install `jb` or set `JB_CLEANUPCODE_BIN`.
- No terminal launch from Unity: set `UNITY_NVIM_TERMINAL_CMD` explicitly.

## License

See [LICENSE](LICENSE).
