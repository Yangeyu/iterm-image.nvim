-- :checkhealth iterm-image 环境自检

local Terminal = require("iterm-image.terminal")

local Health = {}

local MIN_ITERM = { 3, 5 }

function Health.check()
  local h = vim.health
  h.start("iterm-image.nvim")

  if vim.fn.has("nvim-0.10") == 1 then
    h.ok("Neovim 版本满足要求（≥ 0.10）")
  else
    h.error("需要 Neovim 0.10+（依赖 vim.base64）")
  end

  if vim.fn.executable("magick") == 1 then
    h.ok("ImageMagick 可用（GIF 首帧渲染）")
  else
    h.warn("未找到 magick，GIF 将无法渲染", { "brew install imagemagick" })
  end

  if not Terminal.is_iterm2() then
    h.error(
      "未检测到 iTerm2（TERM_PROGRAM / LC_TERMINAL）",
      { "本插件仅支持 iTerm2；其他终端请使用 snacks.nvim 或 image.nvim" }
    )
    return
  end
  h.ok("检测到 iTerm2")

  local version = Terminal.version()
  if not version then
    h.warn("无法确定 iTerm2 版本；multipart 图片传输需要 ≥ 3.5")
    return
  end
  local major, minor = version:match("^(%d+)%.(%d+)")
  major, minor = tonumber(major), tonumber(minor)
  if major and (major > MIN_ITERM[1] or (major == MIN_ITERM[1] and minor >= MIN_ITERM[2])) then
    h.ok("iTerm2 版本 " .. version .. "（≥ 3.5）")
  else
    h.error("iTerm2 版本 " .. version .. " 过旧，multipart 图片传输需要 ≥ 3.5")
  end
end

return Health
