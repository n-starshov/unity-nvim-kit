local function first_existing(paths)
  for _, path in ipairs(paths) do
    if path and path ~= "" and vim.uv.fs_stat(path) then
      return path
    end
  end
end

local function split_path_list(value)
  if not value or value == "" then
    return {}
  end
  return vim.split(value, ":", { plain = true, trimempty = true })
end

local function executable_path(bin)
  local path = vim.fn.exepath(bin)
  if path ~= "" then
    return path
  end
end

local function dotnet_root()
  if vim.env.DOTNET_ROOT and vim.env.DOTNET_ROOT ~= "" then
    return vim.env.DOTNET_ROOT
  end

  local dotnet = vim.fn.exepath("dotnet")
  if dotnet == "" then
    for _, candidate in ipairs({
      "/usr/bin/dotnet",
      "/usr/local/bin/dotnet",
      "/usr/share/dotnet/dotnet",
      "/opt/homebrew/bin/dotnet",
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

  return realpath:match("^(.*)/dotnet$")
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
    vim.fn.expand("~/.dotnet/tools"),
    vim.fs.joinpath(vim.fn.stdpath("data"), "mason", "bin"),
  }) do
    path = prepend_path(path, entry)
  end
  for _, entry in ipairs(split_path_list(vim.env.UNITY_NVIM_EXTRA_PATH)) do
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

      if root then
        cmd_env.DOTNET_ROOT = root
      end

      if not cmd_env.MONO_GAC_PREFIX then
        local mono_gac_prefix = first_existing({
          vim.env.MONO_GAC_PREFIX,
          vim.env.UNITY_MONO_GAC_PREFIX,
          "/Library/Frameworks/Mono.framework/Versions/Current",
        })
        if mono_gac_prefix then
          cmd_env.MONO_GAC_PREFIX = mono_gac_prefix
        end
      end

      if not cmd_env.MSBUILD_EXE_PATH then
        local mono_msbuild = first_existing({
          vim.env.MSBUILD_EXE_PATH,
          vim.env.UNITY_MSBUILD_EXE_PATH,
          executable_path("msbuild"),
          "/Library/Frameworks/Mono.framework/Versions/Current/Commands/msbuild",
        })
        if mono_msbuild then
          cmd_env.MSBUILD_EXE_PATH = mono_msbuild
        end
      end

      if not cmd_env.MSBuildSDKsPath then
        local msbuild_sdks = first_existing({
          vim.env.MSBuildSDKsPath,
          vim.env.UNITY_MSBUILD_SDKS_PATH,
          "/usr/lib/mono/msbuild/Current/bin/Sdks",
          "/Library/Frameworks/Mono.framework/Versions/Current/lib/mono/msbuild/Current/bin/Sdks",
        })
        if msbuild_sdks then
          cmd_env.MSBuildSDKsPath = msbuild_sdks
        end
      end

      if not cmd_env.MSBuildExtensionsPath then
        local msbuild_extensions = first_existing({
          vim.env.MSBuildExtensionsPath,
          vim.env.UNITY_MSBUILD_EXTENSIONS_PATH,
          "/usr/lib/mono/xbuild",
          "/Library/Frameworks/Mono.framework/Versions/Current/lib/mono/xbuild",
        })
        if msbuild_extensions then
          cmd_env.MSBuildExtensionsPath = msbuild_extensions
        end
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
