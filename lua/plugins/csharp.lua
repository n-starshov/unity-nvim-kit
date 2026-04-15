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

local function dotnet_bin()
  local dotnet = vim.fn.exepath("dotnet")
  if dotnet ~= "" then
    return vim.fs.dirname(dotnet)
  end

  for _, candidate in ipairs({
    "/opt/homebrew/bin/dotnet",
    "/usr/local/bin/dotnet",
    "/usr/local/share/dotnet/dotnet",
  }) do
    if vim.fn.executable(candidate) == 1 then
      return vim.fs.dirname(candidate)
    end
  end
end

local function mono_paths()
  local paths = {}

  local function add(path)
    if path and path ~= "" and not vim.tbl_contains(paths, path) then
      table.insert(paths, path)
    end
  end

  local mono = vim.fn.exepath("mono")
  if mono ~= "" then
    add(vim.fs.dirname(mono))
  end

  local msbuild = vim.fn.exepath("msbuild")
  if msbuild ~= "" then
    add(vim.fs.dirname(msbuild))
  end

  add("/Library/Frameworks/Mono.framework/Versions/Current/Commands")
  add("/opt/homebrew/bin")

  return paths
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

return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}
      opts.servers.csharp_ls = false
      opts.servers.omnisharp = false

      local roslyn = opts.servers.roslyn_ls or {}
      local cmd_env = roslyn.cmd_env or {}
      local root = dotnet_root()
      local bin = dotnet_bin()

      if root then
        cmd_env.DOTNET_ROOT = root
      end
      cmd_env.PATH = prepend_path(cmd_env.PATH or vim.env.PATH or "", bin)
      for _, path in ipairs(mono_paths()) do
        cmd_env.PATH = prepend_path(cmd_env.PATH, path)
      end
      cmd_env.TMPDIR = cmd_env.TMPDIR
        or (vim.env.TMPDIR and vim.env.TMPDIR ~= "" and vim.fn.resolve(vim.env.TMPDIR) or nil)

      roslyn.cmd = {
        vim.fn.expand("~/.dotnet/tools/roslyn-language-server"),
        "--logLevel",
        "Information",
        "--extensionLogDirectory",
        vim.fs.joinpath(vim.uv.os_tmpdir(), "roslyn_ls/logs"),
        "--stdio",
      }
      roslyn.cmd_env = cmd_env

      opts.servers.roslyn_ls = roslyn
    end,
  },
}
