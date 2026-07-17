# iterm-image.nvim

专为 iTerm2 定制的 Neovim 图片查看器。打开图片文件（png/jpg/gif/webp 等）时，
用 iTerm2 **原生图片协议**（OSC 1337）把图片渲染在窗口内。

## 为什么不用现成插件

在 iTerm2 上，两条主流路线都有实测问题：

- **Kitty 图形协议**（snacks.nvim / image.nvim 的 kitty 后端）：iTerm2 的协议实现
  不完整，切换图片时旧图残留、堆叠。
- **ueberzugpp 外部进程**：它和 nvim 同时往终端写数据，转义序列被撕裂后
  满屏 base64 乱码。

本插件的对策：

1. 原生协议把图片画进字符单元，nvim 重绘即覆盖，无残留。
2. multipart 分块传输（`MultipartFile`/`FilePart`/`FileEnd`），每块是一条完整的
   小转义序列，与 nvim 输出交错也不会损坏。
3. 进程内经 `v:stderr` 通道写终端，不开外部进程抢 tty。

## 要求

- iTerm2 ≥ 3.5（multipart 支持）
- Neovim ≥ 0.10（`vim.base64`）
- ImageMagick（可选，仅 GIF 需要）：GIF 只渲染首帧——动图整体发给 iTerm2
  会触发全帧解码与循环播放，大文件足以卡死终端；未安装 magick 时 GIF 跳过渲染

安装后可用 `:checkhealth iterm-image` 自检环境。

## 安装（lazy.nvim）

```lua
{
  "Yangeyu/iterm-image.nvim",
  config = function()
    require("iterm-image").setup()
  end,
}
```

## 配置项（默认值）

```lua
require("iterm-image").setup({
  -- 接管的文件通配符
  patterns = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.bmp", "*.tiff", "*.ico" },
  -- 图片与窗口边缘的间距（单位：字符格）
  margin = { top = 1, right = 2, bottom = 2, left = 2 },
  -- 每条 FilePart 的 base64 字符数
  chunk_size = 2048,
  -- 超过此大小不渲染
  max_file_size = 20 * 1024 * 1024,
  -- 刷新防抖窗口（毫秒）
  debounce_ms = 60,
})
```

## 命令

- `:ItermImageRefresh` — 清屏并重新渲染（画面异常时的手动兜底）

## 模块结构

```
lua/iterm-image/
├── init.lua      入口：装配配置、autocmd 与命令（唯一注册事件的地方）
├── config.lua    默认配置与用户配置合并
├── protocol.lua  OSC 1337 序列构造（纯函数，无 IO）
├── terminal.lua  终端探测与底层写入
├── buffer.lua    图片 buffer 接管、窗口选项保存/恢复
├── renderer.lua  几何计算、异步读文件、渲染调度与防抖
└── health.lua    :checkhealth 自检
```

## License

MIT
