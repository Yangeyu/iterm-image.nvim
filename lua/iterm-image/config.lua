-- 配置：默认值定义与用户配置合并。
-- 只存数据，不含任何行为，供其余模块只读访问。

---@class ItermImage.Margin 图片与窗口边缘的间距（单位：字符格）
---@field top integer
---@field right integer
---@field bottom integer
---@field left integer

---@class ItermImage.Config
---@field patterns string[] 接管的文件通配符
---@field margin ItermImage.Margin
---@field chunk_size integer 每条 FilePart 序列携带的 base64 字符数
---@field max_file_size integer 超过此字节数的文件不渲染
---@field debounce_ms integer 刷新防抖窗口（毫秒）

local Config = {}

---@type ItermImage.Config
Config.defaults = {
  patterns = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.bmp", "*.tiff", "*.ico" },
  margin = { top = 1, right = 2, bottom = 2, left = 2 },
  -- 太大会增加单次 pty 写入被拆分、与 nvim 输出交错的风险
  chunk_size = 2048,
  max_file_size = 20 * 1024 * 1024,
  debounce_ms = 60,
}

---@type ItermImage.Config
Config.options = vim.deepcopy(Config.defaults)

---@param opts? ItermImage.Config 用户配置，深合并覆盖默认值
function Config.setup(opts)
  Config.options = vim.tbl_deep_extend("force", vim.deepcopy(Config.defaults), opts or {})
end

return Config
