local unity_callbacks = {
  Awake = true,
  FixedUpdate = true,
  LateUpdate = true,
  OnAnimatorIK = true,
  OnAnimatorMove = true,
  OnApplicationFocus = true,
  OnApplicationPause = true,
  OnApplicationQuit = true,
  OnAudioFilterRead = true,
  OnBecameInvisible = true,
  OnBecameVisible = true,
  OnChildRectTransformDimensionsChange = true,
  OnCollisionEnter = true,
  OnCollisionEnter2D = true,
  OnCollisionExit = true,
  OnCollisionExit2D = true,
  OnCollisionStay = true,
  OnCollisionStay2D = true,
  OnControllerColliderHit = true,
  OnDestroy = true,
  OnDisable = true,
  OnDrawGizmos = true,
  OnDrawGizmosSelected = true,
  OnEnable = true,
  OnGUI = true,
  OnJointBreak = true,
  OnJointBreak2D = true,
  OnMouseDown = true,
  OnMouseDrag = true,
  OnMouseEnter = true,
  OnMouseExit = true,
  OnMouseOver = true,
  OnMouseUp = true,
  OnMouseUpAsButton = true,
  OnParticleCollision = true,
  OnParticleSystemStopped = true,
  OnParticleTrigger = true,
  OnParticleUpdateJobScheduled = true,
  OnPostRender = true,
  OnPreCull = true,
  OnPreRender = true,
  OnRenderImage = true,
  OnRenderObject = true,
  OnTransformChildrenChanged = true,
  OnTransformParentChanged = true,
  OnTriggerEnter = true,
  OnTriggerEnter2D = true,
  OnTriggerExit = true,
  OnTriggerExit2D = true,
  OnTriggerStay = true,
  OnTriggerStay2D = true,
  OnValidate = true,
  OnWillRenderObject = true,
  Reset = true,
  Start = true,
  Update = true,
}

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
  local start = vim.fn.fnamemodify(path ~= "" and path or vim.fn.getcwd(), ":p:h")
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

local function is_unity_cs(bufnr)
  if vim.bo[bufnr].filetype ~= "cs" then
    return false
  end

  local file = vim.api.nvim_buf_get_name(bufnr)
  if file == "" then
    return false
  end

  local root = unity_project_root(file)
  if not root then
    return false
  end

  local rel = vim.fs.relpath(root, file) or ""
  rel = rel:gsub("\\", "/")
  return rel:match("^Assets/") ~= nil or rel:match("^Packages/") ~= nil
end

local function diag_code(diag)
  if diag.code then
    return tostring(diag.code)
  end
  local lsp = diag.user_data and diag.user_data.lsp
  if lsp and lsp.code then
    return tostring(lsp.code)
  end
  return ""
end

local function callback_name_from_message(message)
  if not message then
    return nil
  end
  return message:match("'([%a_][%w_]*)'")
end

local function nearest_class_inherits_monobehaviour(bufnr, diag)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  if line_count == 0 then
    return false
  end

  local lnum = (diag.lnum or 0) + 1
  if lnum < 1 then
    lnum = 1
  end
  if lnum > line_count then
    lnum = line_count
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, lnum, false)
  for i = #lines, 1, -1 do
    local line = lines[i]
    if line:find("class", 1, true) then
      local class_line = line:gsub("//.*$", "")
      class_line = class_line:gsub("%s+", " ")
      if class_line:match("%f[%a]class%f[%A]") then
        if class_line:match(":%s*[%w_%.<>, ]*MonoBehaviour%f[%W]") then
          return true
        end
        return false
      end
    end
  end

  return false
end

local function keep_diag(bufnr, diag)
  if not is_unity_cs(bufnr) then
    return true
  end
  if diag_code(diag) ~= "IDE0051" then
    return true
  end

  local callback = callback_name_from_message(diag.message)
  if not (callback and unity_callbacks[callback]) then
    return true
  end

  return not nearest_class_inherits_monobehaviour(bufnr, diag)
end

return {
  {
    "neovim/nvim-lspconfig",
    init = function()
      if vim.g.unity_diag_filter_installed then
        return
      end
      vim.g.unity_diag_filter_installed = true

      local original = vim.deepcopy(vim.diagnostic.handlers)
      for name, handler in pairs(original) do
        vim.diagnostic.handlers[name] = {
          show = function(namespace, bufnr, diagnostics, opts)
            local filtered = vim.tbl_filter(function(diag)
              return keep_diag(bufnr, diag)
            end, diagnostics)
            handler.show(namespace, bufnr, filtered, opts)
          end,
          hide = handler.hide,
        }
      end
    end,
  },
}
