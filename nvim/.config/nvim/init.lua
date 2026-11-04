require("modules.options")
require("modules.theme")
require("modules.lazy")
require("modules.keymaps")

vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    local path = vim.fn.expand("~/.local/share/nvim-launch-count")
    local f = io.open(path, "r")
    local n = f and tonumber(f:read("*a")) or 0
    if f then f:close() end
    f = io.open(path, "w")
    if f then f:write(n + 1) f:close() end
  end,
})
