local function dotnet_root()
  if vim.env.DOTNET_ROOT and vim.env.DOTNET_ROOT ~= "" then
    return vim.env.DOTNET_ROOT
  end

  local dotnet = vim.fn.exepath("dotnet")
  if dotnet == "" then
    for _, candidate in ipairs({
      "/opt/homebrew/bin/dotnet",
      "/usr/local/bin/dotnet",
      "/usr/local/share/dotnet/dotnet",
    }) do
      if vim.fn.executable(candidate) == 1 then
        dotnet = candidate
        break
      end
    end
  end

  if dotnet == "" then
    return nil
  end

  local realpath = vim.uv.fs_realpath(dotnet) or dotnet
  local prefix = realpath:match("^(.*)/bin/dotnet$")
  if prefix then
    return prefix .. "/libexec"
  end
end

local function prepend_path(path, entry)
  if not entry or entry == "" then
    return path
  end

  local parts = vim.split(path or "", ":", { plain = true, trimempty = true })
  if vim.tbl_contains(parts, entry) then
    return path
  end
  table.insert(parts, 1, entry)
  return table.concat(parts, ":")
end

local function build_path()
  local path = vim.env.PATH or ""
  for _, entry in ipairs({
    "/Users/REDACTED/.dotnet/tools",
    "/Users/REDACTED/.local/share/nvim/mason/bin",
    "/opt/homebrew/bin",
    "/Library/Frameworks/Mono.framework/Versions/Current/Commands",
  }) do
    path = prepend_path(path, entry)
  end
  return path
end

local function roslyn_cmd()
  local local_tool = vim.fn.expand("~/.dotnet/tools/roslyn-language-server")
  if vim.fn.executable(local_tool) == 1 then
    return local_tool
  end

  if vim.fn.executable("Microsoft.CodeAnalysis.LanguageServer") == 1 then
    return "Microsoft.CodeAnalysis.LanguageServer"
  end

  if vim.fn.executable("roslyn-language-server") == 1 then
    return "roslyn-language-server"
  end

  return "roslyn-language-server"
end

local function first_existing(paths)
  for _, path in ipairs(paths) do
    if path and path ~= "" and vim.uv.fs_stat(path) then
      return path
    end
  end
end

return {
  {
    "Hoffs/omnisharp-extended-lsp.nvim",
    enabled = false,
  },
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.inlay_hints = opts.inlay_hints or { enabled = true, exclude = {} }
      opts.inlay_hints.exclude = opts.inlay_hints.exclude or {}
      if not vim.tbl_contains(opts.inlay_hints.exclude, "cs") then
        table.insert(opts.inlay_hints.exclude, "cs")
      end

      opts.servers = opts.servers or {}
      opts.servers.csharp_ls = false
      opts.servers.omnisharp = false

      local roslyn = opts.servers.roslyn_ls == true and {} or (opts.servers.roslyn_ls or {})
      local cmd_env = roslyn.cmd_env or {}
      local root = dotnet_root()
      local mono_root = first_existing({
        "/Library/Frameworks/Mono.framework/Versions/Current",
        "/Library/Frameworks/Mono.framework/Versions/6.12.0",
      })
      local mono_commands = mono_root and (mono_root .. "/Commands") or nil
      local mono_msbuild_bin = mono_root and (mono_root .. "/lib/mono/msbuild/Current/bin") or nil
      local mono_xbuild = mono_root and (mono_root .. "/lib/mono/xbuild") or nil
      local mono_msbuild = mono_commands and (mono_commands .. "/msbuild") or nil

      if root then
        cmd_env.DOTNET_ROOT = root
      end

      if mono_root then
        cmd_env.MONO_GAC_PREFIX = mono_root
      end
      if mono_msbuild and vim.fn.executable(mono_msbuild) == 1 then
        cmd_env.MSBUILD_EXE_PATH = mono_msbuild
      end
      if mono_msbuild_bin and vim.uv.fs_stat(mono_msbuild_bin) then
        cmd_env.MSBuildSDKsPath = mono_msbuild_bin .. "/Sdks"
      end
      if mono_xbuild and vim.uv.fs_stat(mono_xbuild) then
        cmd_env.MSBuildExtensionsPath = mono_xbuild
      end

      cmd_env.PATH = build_path()
      cmd_env.TMPDIR = cmd_env.TMPDIR
        or (vim.env.TMPDIR and vim.env.TMPDIR ~= "" and vim.fn.resolve(vim.env.TMPDIR) or nil)

      roslyn.mason = false
      roslyn.cmd = {
        roslyn_cmd(),
        "--logLevel",
        "Information",
        "--extensionLogDirectory",
        vim.fs.joinpath(vim.uv.os_tmpdir(), "roslyn_ls/logs"),
        "--stdio",
      }
      roslyn.cmd_env = cmd_env
      roslyn.settings = vim.tbl_deep_extend("force", roslyn.settings or {}, {
        ["csharp|background_analysis"] = {
          dotnet_analyzer_diagnostics_scope = "openFiles",
          dotnet_compiler_diagnostics_scope = "openFiles",
        },
      })

      opts.servers.roslyn_ls = roslyn
    end,
  },
}
