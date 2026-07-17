-- 渲染调度：窗口几何计算、异步读取文件、写入终端、防抖刷新。

local Config = require("iterm-image.config")
local Protocol = require("iterm-image.protocol")
local Terminal = require("iterm-image.terminal")
local Buffer = require("iterm-image.buffer")

local uv = vim.uv

local Renderer = {}

--- 窗口内容区（扣除边距后）的绘制区域；窗口不可见或太小返回 nil
---@param win integer
---@return ItermImage.Geometry?
local function viewport(win)
  local pos = vim.fn.win_screenpos(win)
  if pos[1] == 0 then
    return nil
  end
  local margin = Config.options.margin
  local width = vim.api.nvim_win_get_width(win) - margin.left - margin.right
  local height = vim.api.nvim_win_get_height(win) - margin.top - margin.bottom
  if width < 1 or height < 1 then
    return nil
  end
  return {
    row = pos[1] + margin.top,
    col = pos[2] + margin.left,
    width = width,
    height = height,
  }
end

--- 异步读取整个文件；完成后在主循环回调 on_done(data) 或 on_done(nil, err)
---@param path string
---@param max_size integer
---@param on_done fun(data: string?, err: string?)
local function read_file(path, max_size, on_done)
  local function done(data, err)
    vim.schedule(function()
      on_done(data, err)
    end)
  end
  uv.fs_open(path, "r", 292, function(open_err, fd)
    if open_err or not fd then
      return done(nil, "无法打开文件: " .. path)
    end
    uv.fs_fstat(fd, function(stat_err, stat)
      if stat_err or not stat or stat.size == 0 then
        uv.fs_close(fd)
        return done(nil, "无法读取文件: " .. path)
      end
      if stat.size > max_size then
        uv.fs_close(fd)
        return done(nil, ("文件超过 %d MB，跳过渲染: %s"):format(max_size / 1024 / 1024, path))
      end
      uv.fs_read(fd, stat.size, 0, function(read_err, data)
        uv.fs_close(fd)
        if read_err or not data then
          return done(nil, "读取失败: " .. path)
        end
        done(data)
      end)
    end)
  end)
end

--- 异步渲染窗口中的图片；读取完成后校验现场（窗口、buffer、几何）仍有效才绘制
---@param win integer
-- 最近一次渲染的成品缓存。补画（被外部 redraw 擦掉后重现）是高频路径，
-- 命中缓存时跳过读文件与 base64 编码，同步重发序列，把擦除到重现的
-- 间隙压到最小以避免可感知的闪烁。
---@type { path: string, mtime: integer, geometry: ItermImage.Geometry, writes: string[] }?
local last_render = nil

---@param a ItermImage.Geometry
---@param b ItermImage.Geometry
---@return boolean
local function geometry_equal(a, b)
  return a.row == b.row and a.col == b.col and a.width == b.width and a.height == b.height
end

---@param path string
---@return integer? mtime 文件修改时间（秒）；stat 失败返回 nil
local function file_mtime(path)
  local stat = uv.fs_stat(path)
  return stat and stat.mtime.sec or nil
end

function Renderer.render(win)
  if not (Terminal.is_iterm2() and vim.api.nvim_win_is_valid(win)) then
    return
  end
  local buf = vim.api.nvim_win_get_buf(win)
  local path = Buffer.path(buf)
  local geometry = viewport(win)
  if not path or not geometry then
    return
  end

  local mtime = file_mtime(path)
  if
    last_render
    and last_render.path == path
    and last_render.mtime == mtime
    and geometry_equal(last_render.geometry, geometry)
  then
    Terminal.write(last_render.writes)
    return
  end

  read_file(path, Config.options.max_file_size, function(data, err)
    if not data then
      vim.notify_once("iterm-image: " .. err, vim.log.levels.WARN)
      return
    end
    if not vim.api.nvim_win_is_valid(win) or vim.api.nvim_win_get_buf(win) ~= buf then
      return
    end
    local fresh_geometry = viewport(win)
    if not fresh_geometry then
      return
    end
    local writes = Protocol.multipart(data, fresh_geometry, Config.options.chunk_size)
    last_render = {
      path = path,
      mtime = mtime,
      geometry = fresh_geometry,
      writes = writes,
    }
    Terminal.write(writes)
  end)
end

-- 防抖状态：合并密集事件为一次刷新；期间任一请求要求清屏则本轮清屏
local pending = false
local want_clear = false

--- 刷新所有可见图片。clear = true 时先整屏重绘，清掉终端上的旧图；
--- delay 可覆盖默认防抖延迟（毫秒），用于需要尽快补画的场景。
---@param opts? { clear?: boolean, delay?: integer }
function Renderer.refresh(opts)
  want_clear = want_clear or (opts ~= nil and opts.clear == true)
  if pending then
    return
  end
  pending = true
  vim.defer_fn(function()
    pending = false
    local clear = want_clear
    want_clear = false
    if clear then
      vim.cmd.redraw({ bang = true })
    end
    for _, win in ipairs(Buffer.windows()) do
      Renderer.render(win)
    end
  end, (opts and opts.delay) or Config.options.debounce_ms)
end

return Renderer
