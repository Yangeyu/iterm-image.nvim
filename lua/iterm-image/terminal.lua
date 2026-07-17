-- 终端能力探测与底层写入。

local Terminal = {}

--- 是否运行在 iTerm2 中（LC_TERMINAL 覆盖 ssh 远程场景）
---@return boolean
function Terminal.is_iterm2()
  return vim.env.TERM_PROGRAM == "iTerm.app" or vim.env.LC_TERMINAL == "iTerm2"
end

--- iTerm2 版本号字符串，如 "3.6.6"；探测不到返回 nil
---@return string?
function Terminal.version()
  return vim.env.TERM_PROGRAM_VERSION or vim.env.LC_TERMINAL_VERSION
end

--- 逐条把序列写入终端。
--- 走 v:stderr 通道以绕过 nvim 对 stdout 的接管；每条序列单独写入，
--- 保证即使与 nvim 的 UI 输出交错，交错也只发生在序列之间而非内部。
---@param writes string[]
function Terminal.write(writes)
  for _, seq in ipairs(writes) do
    vim.fn.chansend(vim.v.stderr, seq)
  end
end

return Terminal
