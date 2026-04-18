# Unity + Neovim Setup

## Unity package policy

Use only one of these Unity IDE integration packages:

- `com.unity.ide.visualstudio`
- `com.unity.ide.rider`

Do not install any other editor integration package.

## Unity External Tools

- `External Script Editor`: `<path-to-your-nvim-config>/bin/unity-nvim-open`
- `External Script Editor Args`: `$(File) $(Line) $(Column)`

Enable project file generation for Unity assets/packages you want Roslyn to see.

## Start Neovim for Unity work

Start your main Neovim session with:

```sh
<path-to-your-nvim-config>/bin/unity-nvim-session
```

This starts Neovim on fixed socket so Unity can reopen files in same session.

## Optional environment variables

- `UNITY_NVIM_BIN`: explicit Neovim executable path
- `UNITY_NVIM_SOCKET`: socket path (default: `$XDG_STATE_HOME/nvim/unity.sock`)
- `UNITY_NVIM_TERMINAL_CMD`: terminal launch command used when socket session is not running
- `UNITY_NVIM_TERMINAL_APP`: macOS app name/path for `open -na ... --args` fallback (default: `Terminal`)
- `UNITY_NVIM_EXTRA_PATH`: extra `PATH` entries (colon-separated) for Roslyn/CleanupCode commands
- `DOTNET_ROOT`: explicit .NET SDK root when auto-detection is wrong
- `JB_CLEANUPCODE_BIN`: explicit JetBrains `jb` executable path

Linux examples:

```sh
export UNITY_NVIM_TERMINAL_CMD='ghostty -e'
# or:
export UNITY_NVIM_TERMINAL_CMD='kitty -e'
```
