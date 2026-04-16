# Unity + Neovim Setup

## Unity package policy

Use only one of these Unity IDE integration packages:

- `com.unity.ide.visualstudio`
- `com.unity.ide.rider`

Do not install any other editor integration package.

## Unity External Tools

- `External Script Editor`: `/Users/REDACTED/.config/nvim/bin/unity-nvim-open`
- `External Script Editor Args`: `$(File) $(Line) $(Column)`

Enable project file generation for Unity assets/packages you want Roslyn to see.

## Start Neovim for Unity work

Start your main Neovim session with:

```sh
/Users/REDACTED/.config/nvim/bin/unity-nvim-session
```

This starts Neovim on fixed socket so Unity can reopen files in same session.
