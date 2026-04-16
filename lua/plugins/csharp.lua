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
    "/Users/REDACTED/.local/share/nvim/mason/bin",
    "/opt/homebrew/bin",
    "/Library/Frameworks/Mono.framework/Versions/Current/Commands",
  }) do
    path = prepend_path(path, entry)
  end
  return path
end

local function find_solution(root_dir)
  if not root_dir or root_dir == "" then
    return nil
  end

  local matches = vim.fs.find(function(name, path)
    return path == root_dir and (name:match("%.sln$") or name:match("%.slnx$"))
  end, {
    path = root_dir,
    type = "file",
    limit = 1,
  })

  return matches[1]
end

return {
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "Hoffs/omnisharp-extended-lsp.nvim",
    },
    opts = function(_, opts)
      opts.inlay_hints = opts.inlay_hints or { enabled = true, exclude = {} }
      opts.inlay_hints.exclude = opts.inlay_hints.exclude or {}
      if not vim.tbl_contains(opts.inlay_hints.exclude, "cs") then
        table.insert(opts.inlay_hints.exclude, "cs")
      end

      opts.servers = opts.servers or {}
      opts.servers.csharp_ls = false
      opts.servers.roslyn_ls = false

      local omnisharp = opts.servers.omnisharp == true and {} or (opts.servers.omnisharp or {})
      local cmd_env = omnisharp.cmd_env or {}
      local root = dotnet_root()

      if root then
        cmd_env.DOTNET_ROOT = root
      end
      cmd_env.PATH = build_path()
      cmd_env.TMPDIR = cmd_env.TMPDIR
        or (vim.env.TMPDIR and vim.env.TMPDIR ~= "" and vim.fn.resolve(vim.env.TMPDIR) or nil)

      local existing_on_new_config = omnisharp.on_new_config
      omnisharp.on_new_config = function(new_config, root_dir)
        if existing_on_new_config then
          existing_on_new_config(new_config, root_dir)
        end
        new_config.cmd_source = find_solution(root_dir) or root_dir
      end

      local existing_on_attach = omnisharp.on_attach
      omnisharp.on_attach = function(client, bufnr)
        client.server_capabilities.inlayHintProvider = false
        client.server_capabilities.semanticTokensProvider = nil
        if existing_on_attach then
          existing_on_attach(client, bufnr)
        end
      end

      omnisharp.cmd = function(dispatchers, config)
        return vim.lsp.rpc.start({
          vim.fn.expand("~/.local/share/nvim/mason/bin/OmniSharp"),
          "-s",
          config.cmd_source or config.root_dir,
          "-l",
          "warning",
          "-z",
          "--hostPID",
          tostring(vim.fn.getpid()),
          "DotNet:enablePackageRestore=false",
          "--encoding",
          "utf-8",
          "--languageserver",
        }, dispatchers, {
          cwd = config.cmd_cwd or config.root_dir,
          env = config.cmd_env,
        })
      end
      omnisharp.cmd_env = cmd_env
      omnisharp.handlers = vim.tbl_deep_extend("force", omnisharp.handlers or {}, {
        ["textDocument/definition"] = require("omnisharp_extended").definition_handler,
        ["textDocument/typeDefinition"] = require("omnisharp_extended").type_definition_handler,
        ["textDocument/references"] = require("omnisharp_extended").references_handler,
        ["textDocument/implementation"] = require("omnisharp_extended").implementation_handler,
      })
      omnisharp.enable_roslyn_analyzers = false
      omnisharp.organize_imports_on_format = true
      omnisharp.enable_import_completion = true
      omnisharp.settings = vim.tbl_deep_extend("force", omnisharp.settings or {}, {
        FormattingOptions = {
          EnableEditorConfigSupport = true,
          OrganizeImports = true,
        },
        MsBuild = {
          LoadProjectsOnDemand = false,
        },
        RoslynExtensionsOptions = {
          EnableAnalyzersSupport = false,
          EnableImportCompletion = true,
          AnalyzeOpenDocumentsOnly = false,
          EnableDecompilationSupport = true,
        },
        Sdk = {
          IncludePrereleases = true,
        },
      })

      opts.servers.omnisharp = omnisharp
    end,
  },
}
