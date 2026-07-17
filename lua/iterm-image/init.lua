-- iterm-image.nvim —— 专为 iTerm2 定制的图片查看器。
-- 打开图片文件时，用 iTerm2 原生图片协议（OSC 1337）把图片渲染在窗口内。
--
-- 入口模块只做装配：合并配置、注册 autocmd 与用户命令。
-- 事件如何触发渲染全部定义在此处，子模块不注册任何 autocmd，控制流单点可查：
--   protocol  纯序列构造    terminal  终端探测/写入
--   buffer    buffer 接管   renderer  渲染调度
--   config    配置          health    环境自检

local M = {}

local AUGROUP = "ItermImage"

---@param opts? ItermImage.Config
function M.setup(opts)
  if vim.fn.has("nvim-0.10") == 0 then
    vim.notify("iterm-image.nvim 需要 Neovim 0.10+", vim.log.levels.ERROR)
    return
  end

  local Config = require("iterm-image.config")
  local Buffer = require("iterm-image.buffer")
  local Renderer = require("iterm-image.renderer")
  local Terminal = require("iterm-image.terminal")

  Config.setup(opts)
  local group = vim.api.nvim_create_augroup(AUGROUP, { clear = true })

  -- 接管图片文件的读取；实际渲染由随后的 BufWinEnter 触发
  vim.api.nvim_create_autocmd("BufReadCmd", {
    group = group,
    pattern = Config.options.patterns,
    desc = "接管图片 buffer",
    callback = function(ev)
      Buffer.attach(ev.buf, ev.file)
      if not Terminal.is_iterm2() then
        vim.notify_once("iterm-image: 当前终端不是 iTerm2，无法渲染图片", vim.log.levels.WARN)
      end
    end,
  })

  -- 窗口展示图片 buffer：装饰窗口并渲染；
  -- 展示普通 buffer：若窗口刚从图片切走，恢复选项并清掉终端上的旧图
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = group,
    desc = "图片窗口的进入/离开处理",
    callback = function(ev)
      local win = vim.api.nvim_get_current_win()
      if Buffer.is_image(ev.buf) then
        Buffer.decorate(win)
        Renderer.refresh({ clear = true })
      elseif Buffer.restore(win) then
        Renderer.refresh({ clear = true })
      end
    end,
  })

  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    desc = "图片窗口关闭后清理",
    callback = function(ev)
      Buffer.forget(tonumber(ev.match) or -1)
      if Buffer.is_image(ev.buf) then
        Renderer.refresh({ clear = true })
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "VimResized", "WinResized", "FocusGained" }, {
    group = group,
    desc = "布局变化后重绘图片",
    callback = function()
      if #Buffer.windows() > 0 then
        Renderer.refresh({ clear = true })
      end
    end,
  })

  -- 焦点切换会重绘图片窗口（NormalNC 高亮、光标动画等），把画在字符单元上的
  -- 图片抹掉；切换完成后补画一次（不清屏，直接覆盖绘制，避免闪烁）。
  -- 光标动画类插件（如 smear-cursor）的拖尾会持续数百毫秒，可能在首次补画后
  -- 再次擦掉部分图片，故延迟后再补画一轮兜底
  vim.api.nvim_create_autocmd("WinEnter", {
    group = group,
    desc = "窗口切换后补画图片",
    callback = function()
      if #Buffer.windows() == 0 then
        return
      end
      Renderer.refresh({ clear = false })
      vim.defer_fn(function()
        if #Buffer.windows() > 0 then
          Renderer.refresh({ clear = false })
        end
      end, 400)
    end,
  })

  vim.api.nvim_create_user_command("ItermImageRefresh", M.refresh, {
    desc = "清屏并重新渲染图片",
  })
end

--- 清屏并重新渲染所有可见图片（画面异常时的手动兜底）
function M.refresh()
  require("iterm-image.renderer").refresh({ clear = true })
end

return M
