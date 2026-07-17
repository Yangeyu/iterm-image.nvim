-- 图片 buffer 的接管与窗口装饰。
-- 约定：被接管的 buffer 以 b:iterm_image_path 标记图片绝对路径，
-- 该变量是本模块对外的唯一状态，其他模块经 Buffer.path() 读取。

local Buffer = {}

local BUF_VAR = "iterm_image_path"

-- 展示图片时应用的窗口局部选项；进入时保存原值、离开时恢复
local WINDOW_OPTS = {
  number = false,
  relativenumber = false,
  cursorline = false,
  signcolumn = "no",
  wrap = false,
  fillchars = "eob: ",
  -- 活动/非活动窗口共用同一高亮：焦点切换时 nvim 无需以 NormalNC 重绘
  -- 本窗口，画在字符单元上的图片就不会被擦掉（擦掉再补画会造成闪烁）
  winhighlight = "NormalNC:Normal",
}

---@type table<integer, table<string, any>> winid -> 覆盖前的选项原值
local saved_options = {}

--- 接管一个图片文件的 buffer：不载入二进制内容，只留占位空行。
---@param buf integer
---@param file string BufReadCmd 传入的文件名
function Buffer.attach(buf, file)
  vim.bo[buf].swapfile = false
  vim.bo[buf].buftype = "nowrite"
  vim.bo[buf].undolevels = -1
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "" })
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false
  -- 独立 filetype：便于 statusline 识别，也便于用户为图片 buffer 单独
  -- 关闭会重绘窗口内容的插件（如光标拖尾动画）
  vim.bo[buf].filetype = "iterm-image"
  vim.b[buf][BUF_VAR] = vim.fn.fnamemodify(file, ":p")
end

--- buffer 对应的图片路径；非图片 buffer 返回 nil
---@param buf integer
---@return string?
function Buffer.path(buf)
  return vim.b[buf][BUF_VAR]
end

---@param buf integer
---@return boolean
function Buffer.is_image(buf)
  return Buffer.path(buf) ~= nil
end

--- 当前正在显示图片 buffer 的所有窗口
---@return integer[]
function Buffer.windows()
  return vim.tbl_filter(function(win)
    return Buffer.is_image(vim.api.nvim_win_get_buf(win))
  end, vim.api.nvim_list_wins())
end

--- 为展示图片调整窗口选项（幂等；原值仅在首次覆盖时保存）
---@param win integer
function Buffer.decorate(win)
  if saved_options[win] then
    return
  end
  local previous = {}
  for name, value in pairs(WINDOW_OPTS) do
    previous[name] = vim.wo[win][name]
    vim.wo[win][name] = value
  end
  saved_options[win] = previous
end

--- 恢复窗口选项原值。
---@param win integer
---@return boolean restored 该窗口此前是否处于装饰状态
function Buffer.restore(win)
  local previous = saved_options[win]
  if not previous then
    return false
  end
  saved_options[win] = nil
  if vim.api.nvim_win_is_valid(win) then
    for name, value in pairs(previous) do
      vim.wo[win][name] = value
    end
  end
  return true
end

--- 窗口已关闭，丢弃其保存的状态
---@param win integer
function Buffer.forget(win)
  saved_options[win] = nil
end

return Buffer
