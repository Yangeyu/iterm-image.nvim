-- OSC 1337（iTerm2 原生图片协议）转义序列构造。
-- 全部是纯函数：只生成字符串、不做任何 IO，可独立测试。
--
-- 为什么用 multipart（MultipartFile / FilePart / FileEnd）而不是单条序列：
-- 图片数据动辄数 MB，单条序列会被 pty 拆成多次 write，一旦 nvim 的重绘输出
-- 插进序列中间，序列即损坏，剩余 base64 会被终端当作普通文本刷屏。
-- multipart 把数据切成许多条独立完整的小序列，条与条之间被打断也无害。

local ESC, BEL = "\27", "\7"

---@class ItermImage.Geometry 绘制区域（终端屏幕坐标，从 1 开始；尺寸单位为字符格）
---@field row integer
---@field col integer
---@field width integer
---@field height integer

local Protocol = {}

---@return string
function Protocol.save_cursor()
  return ESC .. "7"
end

---@return string
function Protocol.restore_cursor()
  return ESC .. "8"
end

---@param row integer
---@param col integer
---@return string
function Protocol.cursor_to(row, col)
  return string.format("%s[%d;%dH", ESC, row, col)
end

---@param byte_size integer 图片原始字节数
---@param geometry ItermImage.Geometry
---@return string
local function multipart_begin(byte_size, geometry)
  return string.format(
    "%s]1337;MultipartFile=inline=1;size=%d;width=%d;height=%d;preserveAspectRatio=1%s",
    ESC,
    byte_size,
    geometry.width,
    geometry.height,
    BEL
  )
end

---@param chunk string base64 片段
---@return string
local function file_part(chunk)
  return string.format("%s]1337;FilePart=%s%s", ESC, chunk, BEL)
end

---@return string
local function multipart_end()
  return string.format("%s]1337;FileEnd%s", ESC, BEL)
end

--- 把一张图片编码为一组待写入终端的序列。
--- 首条：保存光标并移动到绘制点、声明图片；中间：数据分块；
--- 尾条：重新定位一次（防止传输期间 nvim 移动过终端光标）、收尾、恢复光标。
---@param data string 图片原始字节
---@param geometry ItermImage.Geometry
---@param chunk_size integer
---@return string[] writes 逐条写入终端的完整序列
function Protocol.multipart(data, geometry, chunk_size)
  local writes = {}
  writes[#writes + 1] = Protocol.save_cursor()
    .. Protocol.cursor_to(geometry.row, geometry.col)
    .. multipart_begin(#data, geometry)

  local b64 = vim.base64.encode(data)
  for i = 1, #b64, chunk_size do
    writes[#writes + 1] = file_part(b64:sub(i, i + chunk_size - 1))
  end

  writes[#writes + 1] = Protocol.cursor_to(geometry.row, geometry.col)
    .. multipart_end()
    .. Protocol.restore_cursor()
  return writes
end

return Protocol
