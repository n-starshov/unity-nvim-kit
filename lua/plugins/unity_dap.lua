local function dotnet_exe()
  local dotnet = vim.fn.exepath("dotnet")
  if dotnet ~= "" then
    return dotnet
  end

  for _, candidate in ipairs({
    "/usr/bin/dotnet",
    "/usr/local/bin/dotnet",
    "/usr/share/dotnet/dotnet",
    "/opt/homebrew/bin/dotnet",
    "/usr/local/share/dotnet/dotnet",
  }) do
    if vim.fn.executable(candidate) == 1 then
      return candidate
    end
  end
end

local function unity_adapter_root()
  local data = vim.fn.stdpath("data")
  for _, root in ipairs({
    vim.fs.joinpath(data, "vstuc", "extension"),
    vim.fs.joinpath(data, "vstuc"),
  }) do
    if vim.uv.fs_stat(vim.fs.joinpath(root, "bin", "UnityDebugAdapter.dll")) then
      return root
    end
  end
end

local function is_unity_root(root)
  if not root or root == "" then
    return false
  end

  for _, marker in ipairs({ "Assets", "Packages", "ProjectSettings" }) do
    local stat = vim.uv.fs_stat(vim.fs.joinpath(root, marker))
    if not stat or stat.type ~= "directory" then
      return false
    end
  end

  return true
end

local function unity_project_root(path)
  path = path ~= "" and path or vim.fn.getcwd()
  local start = vim.fn.fnamemodify(path, ":p:h")

  local found = vim.fs.find(function(name, candidate)
    if name ~= "Assets" then
      return false
    end
    return is_unity_root(vim.fs.dirname(candidate))
  end, {
    path = start,
    upward = true,
    type = "directory",
    limit = 1,
  })

  if found[1] then
    return vim.fs.dirname(found[1])
  end
end

local function current_unity_project_root()
  local bufname = vim.api.nvim_buf_get_name(0)
  return unity_project_root(bufname) or unity_project_root(vim.fn.getcwd())
end

local function unity_project_path()
  local root = current_unity_project_root()
  if root then
    return root
  end

  return vim.fn.input("Unity project path: ", vim.fn.getcwd(), "dir")
end

local function unity_endpoint()
  return vim.fn.input("Unity endpoint: ", "127.0.0.1:56000")
end

local function editor_instance_path(root)
  return root and vim.fs.joinpath(root, "..", "Library", "EditorInstance.json") or nil
end

local function read_editor_instance(root)
  local path = editor_instance_path(root)
  if not path or not vim.uv.fs_stat(path) then
    return nil, path
  end

  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return nil, path
  end

  local decode_ok, data = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not decode_ok or type(data) ~= "table" then
    return nil, path
  end

  return data, path
end

local function unity_endpoint_from_project(root)
  local data = read_editor_instance(root)
  if not data or type(data.process_id) ~= "number" then
    return nil
  end

  return ("127.0.0.1:%d"):format(56000 + (data.process_id % 1000))
end

local function unity_auto_endpoint()
  local root = current_unity_project_root()
  local endpoint = root and unity_endpoint_from_project(root) or nil
  if endpoint then
    return endpoint
  end
  return unity_endpoint()
end

local function ensure_config(configs, name, config)
  for i, existing in ipairs(configs) do
    if existing.name == name then
      configs[i] = config
      return
    end
  end
  table.insert(configs, config)
end

return {
  {
    "mfussenegger/nvim-dap",
    optional = true,
    config = function()
      local dap = require("dap")
      if LazyVim.has("mason-nvim-dap.nvim") then
        require("mason-nvim-dap").setup(LazyVim.opts("mason-nvim-dap.nvim"))
      end

      vim.api.nvim_set_hl(0, "DapStoppedLine", { default = true, link = "Visual" })

      for name, sign in pairs(LazyVim.config.icons.dap) do
        sign = type(sign) == "table" and sign or { sign }
        vim.fn.sign_define(
          "Dap" .. name,
          { text = sign[1], texthl = sign[2] or "DiagnosticInfo", linehl = sign[3], numhl = sign[3] }
        )
      end

      local vscode = require("dap.ext.vscode")
      local json = require("plenary.json")
      vscode.json_decode = function(str)
        return vim.json.decode(json.json_strip_comments(str))
      end

      local adapter_root = unity_adapter_root()
      local dotnet = dotnet_exe()

      if adapter_root and dotnet and not dap.adapters.vstuc then
        dap.adapters.vstuc = {
          type = "executable",
          command = dotnet,
          args = { vim.fs.joinpath(adapter_root, "bin", "UnityDebugAdapter.dll") },
          options = {
            cwd = vim.fs.joinpath(adapter_root, "bin"),
          },
        }
      end

      dap.configurations.cs = dap.configurations.cs or {}
      ensure_config(dap.configurations.cs, "Attach Unity Editor", {
        name = "Attach Unity Editor",
        type = "vstuc",
        request = "attach",
        projectPath = function()
          return unity_project_path()
        end,
        endPoint = function()
          return unity_auto_endpoint()
        end,
      })
      ensure_config(dap.configurations.cs, "Attach Unity Editor (Endpoint)", {
        name = "Attach Unity Editor (Endpoint)",
        type = "vstuc",
        request = "attach",
        projectPath = function()
          return unity_project_path()
        end,
        endPoint = function()
          return unity_endpoint()
        end,
      })
    end,
    keys = {
      {
        "<leader>dU",
        function()
          local dap = require("dap")
          local root = current_unity_project_root()
          local editor_instance = editor_instance_path(root)
          if editor_instance and not vim.uv.fs_stat(editor_instance) then
            vim.notify(
              "Unity editor instance file not found yet: " .. editor_instance,
              vim.log.levels.WARN,
              { title = "Unity DAP" }
            )
          end
          dap.run({
            name = "Attach Unity Editor",
            type = "vstuc",
            request = "attach",
            projectPath = unity_project_path(),
            endPoint = unity_auto_endpoint(),
          })
        end,
        ft = "cs",
        desc = "Attach Unity Editor",
      },
      {
        "<leader>dE",
        function()
          require("dap").run({
            name = "Attach Unity Editor (Endpoint)",
            type = "vstuc",
            request = "attach",
            projectPath = unity_project_path(),
            endPoint = unity_endpoint(),
          })
        end,
        ft = "cs",
        desc = "Attach Unity Endpoint",
      },
    },
  },
}
