-- File and content pickers: fzf inside a floating terminal buffer.
--
-- No plugin and no background indexer. fzf runs once per invocation, reads a
-- list from fd or ripgrep, and exits; between searches nothing is running.

local M = {}

local function shellescape(s)
    return vim.fn.shellescape(s)
end

local function picker(opts)
    if vim.fn.executable("fzf") ~= 1 then
        vim.notify("fzf is not installed", vim.log.levels.ERROR)
        return
    end

    local out = vim.fn.tempname()
    local width = math.min(110, math.max(60, math.floor(vim.o.columns * 0.8)))
    local height = math.max(12, math.floor(vim.o.lines * 0.7))

    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1),
        col = math.floor((vim.o.columns - width) / 2),
        style = "minimal",
        border = "rounded",
    })

    local preview = "bat --color=always --style=numbers --line-range=:120 -- {}"
    if vim.fn.executable("bat") ~= 1 then
        preview = "sed -n '1,120p' -- {}"
    end

    local cmd = table.concat({
        opts.source,
        "| fzf --height=100% --reverse --no-info --prompt=" .. shellescape(opts.prompt),
        "--preview " .. shellescape(preview),
        "--preview-window 'right,60%,border-left'",
        opts.args or "",
        "> " .. shellescape(out),
    }, " ")

    local function done()
        local lines = {}
        if vim.fn.filereadable(out) == 1 then
            lines = vim.fn.readfile(out)
        end
        pcall(os.remove, out)
        if vim.api.nvim_win_is_valid(win) then
            pcall(vim.api.nvim_win_close, win, true)
        end
        if vim.api.nvim_buf_is_valid(buf) then
            pcall(vim.api.nvim_buf_delete, buf, { force = true })
        end
        local choice = lines[#lines]
        if choice and choice ~= "" then
            opts.on_select(choice)
        end
    end

    vim.fn.jobstart({ "sh", "-c", cmd }, {
        term = true,
        on_exit = function()
            vim.schedule(done)
        end,
    })
    vim.cmd.startinsert()
end

function M.files()
    picker({
        source = "fd --type f --hidden --follow --exclude .git --exclude target --exclude node_modules",
        prompt = "file> ",
        on_select = function(choice)
            vim.cmd.edit(vim.fn.fnameescape(choice))
        end,
    })
end

function M.grep()
    picker({
        source = "printf ''",
        prompt = "rg> ",
        args = "--disabled "
            .. "--bind 'change:reload:sleep 0.05; rg --vimgrep --smart-case --no-messages -- {q} || true' "
            .. "--delimiter : --nth 1,2 "
            .. "--preview 'bat --color=always --style=numbers --highlight-line {2} -- {1}'",
        on_select = function(choice)
            local file, line = choice:match("^(.-):(%d+):")
            if not file then
                return
            end
            vim.cmd.edit(vim.fn.fnameescape(file))
            vim.api.nvim_win_set_cursor(0, { tonumber(line), 0 })
            vim.cmd("normal! zz")
        end,
    })
end

return M
