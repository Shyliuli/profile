-- The coding agent in a terminal split inside the editor.
--
-- `ai` is the wrapper from the profile, and SHY_AGENT picks which agent it
-- runs, so the editor integration does not care whether that is dsh, codex or
-- anything else. The agent keeps its own context; the editor only gives it a
-- terminal.

local M = {}

function M.open()
    local cmd = vim.env.SHY_AGENT or "ai"
    local height = math.max(10, math.floor(vim.o.lines * 0.35))

    vim.cmd("botright " .. height .. "split")
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(0, buf)
    vim.fn.jobstart(cmd, { term = true })
    vim.cmd.startinsert()
end

return M
