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
    "/opt/homebrew/bin",
    "/Library/Frameworks/Mono.framework/Versions/Current/Commands",
  }) do
    path = prepend_path(path, entry)
  end
  return path
end

local function jb_exe()
  local local_tool = vim.fn.expand("~/.dotnet/tools/jb")
  if vim.fn.executable(local_tool) == 1 then
    return local_tool
  end

  local jb = vim.fn.exepath("jb")
  if jb ~= "" then
    return jb
  end
end

local function find_upward(path, matcher)
  local found = vim.fs.find(matcher, {
    path = path,
    upward = true,
    type = "file",
    limit = math.huge,
  })
  return found[1]
end

local function project_target(filename)
  local dir = vim.fs.dirname(filename)
  local solution = find_upward(dir, function(name)
    return name:match("%.sln$")
  end)
  if solution then
    return solution
  end
  return find_upward(dir, function(name)
    return name:match("%.csproj$")
  end)
end

local function relative_path(base, path)
  local rel = vim.fs.relpath(base, path)
  if rel then
    return rel:gsub("\\", "/")
  end

  local normalized = base:gsub("[/\\]+$", "")
  local prefix = normalized .. "/"
  if path:sub(1, #prefix) == prefix then
    return path:sub(#prefix + 1):gsub("\\", "/")
  end

  return vim.fs.basename(path)
end

local function cleanup_formatter(profile)
  local wrapper = vim.fs.joinpath(vim.fn.stdpath("config"), "bin", "csharp-cleanupcode")
  return {
    command = wrapper,
    args = function(_, ctx)
      local target = project_target(ctx.filename)
      local args = { ctx.filename, profile }
      if target then
        args[#args + 1] = target
        args[#args + 1] = relative_path(vim.fs.dirname(target), ctx.filename)
      end
      return args
    end,
    stdin = true,
    cwd = function(_, ctx)
      local target = project_target(ctx.filename)
      return target and vim.fs.dirname(target) or ctx.dirname
    end,
    env = function()
      return {
        PATH = build_path(),
        JB_CLEANUPCODE_BIN = jb_exe(),
      }
    end,
    condition = function(_, ctx)
      return jb_exe() ~= nil and ctx.filename ~= "" and vim.bo[ctx.buf].buftype == ""
    end,
    require_cwd = false,
  }
end

local function run_cleanup(profile)
  require("conform").format({
    async = false,
    lsp_format = "never",
    formatters = { profile == "Built-in: Reformat Code" and "jb_reformat_code" or "jb_cleanupcode" },
    timeout_ms = 30000,
  })
end

return {
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = function(_, opts)
      opts.formatters = opts.formatters or {}
      opts.formatters.jb_reformat_code = cleanup_formatter("Built-in: Reformat Code")
      opts.formatters.jb_cleanupcode = cleanup_formatter("Built-in: Reformat & Apply Syntax Style")

      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters_by_ft.cs = {
        "jb_reformat_code",
        lsp_format = "never",
        timeout_ms = 30000,
      }
    end,
    keys = {
      {
        "<leader>cC",
        function()
          run_cleanup("Built-in: Reformat & Apply Syntax Style")
        end,
        ft = "cs",
        desc = "C# CleanupCode",
      },
    },
    init = function()
      vim.api.nvim_create_user_command("CsharpCleanup", function()
        run_cleanup("Built-in: Reformat & Apply Syntax Style")
      end, { desc = "Run JetBrains CleanupCode for current C# buffer" })
    end,
  },
}
