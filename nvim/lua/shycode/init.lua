-- The profile itself: options, palette, keys, language server, agent.
--
-- The keys below are chosen around one rule: sway owns Ctrl+f, Ctrl+Shift+f
-- and Ctrl+x, so the editor must not want them. Everything else stays close to
-- plain Vim, with arrow keys as first-class movement and arrow-key habits in
-- mind (no hjkl-only behaviour).

local M = {}

-- The editor is the biggest light source on the laptop. A low-contrast dark
-- palette with a #101014 background matches the sway background, so switching
-- between windows never flashes.
local function palette()
    vim.cmd.colorscheme("habamax")
    local hl = vim.api.nvim_set_hl
    hl(0, "Normal", { fg = "#d0d2d6", bg = "#101014" })
    hl(0, "NormalFloat", { fg = "#d0d2d6", bg = "#181a1f" })
    hl(0, "FloatBorder", { fg = "#2a2d34", bg = "#181a1f" })
    hl(0, "LineNr", { fg = "#5a5f68", bg = "#101014" })
    hl(0, "CursorLineNr", { fg = "#d0d2d6", bg = "#101014", bold = true })
    hl(0, "Visual", { bg = "#2a2d34" })
    hl(0, "Comment", { fg = "#6a6f78" })
    hl(0, "Pmenu", { fg = "#d0d2d6", bg = "#181a1f" })
    hl(0, "PmenuSel", { fg = "#101014", bg = "#6ea8fe" })
    hl(0, "StatusLine", { fg = "#8a8f98", bg = "#181a1f" })
    hl(0, "StatusLineNC", { fg = "#5a5f68", bg = "#101014" })
    hl(0, "Search", { fg = "#101014", bg = "#e5c07b" })
    hl(0, "IncSearch", { fg = "#101014", bg = "#e06c75" })
    hl(0, "DiagnosticVirtualTextError", { fg = "#e06c75", bg = "#101014" })
    hl(0, "DiagnosticVirtualTextWarn", { fg = "#e5c07b", bg = "#101014" })
    hl(0, "DiagnosticVirtualTextInfo", { fg = "#6ea8fe", bg = "#101014" })
    hl(0, "DiagnosticVirtualTextHint", { fg = "#6a6f78", bg = "#101014" })
    hl(0, "DiagnosticUnderlineError", { undercurl = true, sp = "#e06c75" })
    hl(0, "DiagnosticUnderlineWarn", { undercurl = true, sp = "#e5c07b" })

    -- Fenced code in Markdown is parsed by its own language, whose groups
    -- also need to fall back to the generic names the colorscheme defines.
    for _, lang in ipairs({ "c", "lua", "query", "vim" }) do
        local query = vim.treesitter.query.get(lang, "highlights")
        if query then
            for _, name in ipairs(query.captures) do
                if name:sub(1, 1) ~= "_" then
                    hl(0, "@" .. name .. "." .. lang, { link = "@" .. name })
                end
            end
        end
    end

    -- Neovim's Treesitter highlighter appends the language to capture names,
    -- so Markdown needs the language-specific groups, not just the parents.
    local function markdown(name, opts)
        hl(0, "@" .. name, opts)
        hl(0, "@" .. name .. ".markdown", opts)
        hl(0, "@" .. name .. ".markdown_inline", opts)
    end

    markdown("markup.heading", { fg = "#6ea8fe", bold = true })
    markdown("markup.heading.1", { fg = "#6ea8fe", bold = true })
    markdown("markup.heading.2", { fg = "#56b6c2", bold = true })
    markdown("markup.heading.3", { fg = "#e5c07b", bold = true })
    markdown("markup.heading.4", { fg = "#98c379", bold = true })
    markdown("markup.heading.5", { fg = "#c678dd", bold = true })
    markdown("markup.heading.6", { fg = "#abb2bf", bold = true })
    markdown("markup.strong", { bold = true })
    markdown("markup.italic", { italic = true })
    markdown("markup.strikethrough", { strikethrough = true })
    markdown("markup.raw", { fg = "#e5c07b", bg = "#181a1f" })
    markdown("markup.raw.block", { bg = "#181a1f" })
    markdown("markup.link", { fg = "#56b6c2" })
    markdown("markup.link.label", { fg = "#56b6c2" })
    markdown("markup.link.url", { fg = "#6ea8fe", underline = true })
    markdown("markup.list", { fg = "#e5c07b" })
    markdown("markup.list.checked", { fg = "#98c379" })
    markdown("markup.list.unchecked", { fg = "#8a8f98" })
    markdown("markup.quote", { fg = "#8a8f98" })
    markdown("punctuation.special", { fg = "#6a6f78" })
    markdown("punctuation.delimiter", { fg = "#6a6f78" })
    markdown("label", { fg = "#c678dd" })
    markdown("keyword.directive", { fg = "#c678dd" })
    markdown("string.escape", { fg = "#e06c75" })
end

local function options()
    local o = vim.opt
    o.number = true
    o.relativenumber = true
    o.numberwidth = 3

    -- No sign column: diagnostics arrive as virtual text, so the text area
    -- never shifts and nothing redraws when a message appears.
    o.signcolumn = "no"
    o.cursorline = false
    o.wrap = false
    o.scrolloff = 6
    o.sidescrolloff = 4

    o.expandtab = true
    o.tabstop = 4
    o.shiftwidth = 4
    o.softtabstop = 4
    o.smartindent = true

    o.ignorecase = true
    o.smartcase = true
    o.incsearch = true
    o.hlsearch = true

    o.splitright = true
    o.splitbelow = true
    o.mouse = "a"
    o.updatetime = 300
    o.timeoutlen = 400
    o.jumpoptions = "view"

    -- Nothing on disk that a crash could leave behind or a timer could write.
    o.swapfile = false
    o.backup = false
    o.writebackup = false
    o.undofile = false

    o.termguicolors = true
    o.laststatus = 2
    o.cmdheight = 1
    o.wildmode = "longest:full,full"
    o.shortmess:append("IcF")
    o.statusline = "%f%m %= %{&filetype}  %l:%c  %P"

    -- The external providers (node, perl, ruby, python) are unused and only
    -- slow startup down.
    vim.g.loaded_node_provider = 0
    vim.g.loaded_perl_provider = 0
    vim.g.loaded_ruby_provider = 0
    vim.g.loaded_python3_provider = 0

    -- System clipboard through wl-clipboard; without it, yanking would fail.
    -- The clipboard often holds a screenshot (image/png) and plain `wl-paste`
    -- then hands Neovim raw PNG bytes, which `p` inserts as garbage. Asking for
    -- text only turns that into a clean "not available" instead.
    if vim.fn.executable("wl-copy") == 1 then
        o.clipboard = "unnamedplus"
        vim.g.clipboard = {
            name = "wl-clipboard",
            copy = { ["+"] = { "wl-copy" }, ["*"] = { "wl-copy" } },
            paste = {
                ["+"] = { "wl-paste", "--type", "text/plain", "--no-newline" },
                ["*"] = { "wl-paste", "--type", "text/plain", "--no-newline" },
            },
            cache_enabled = 0,
        }
    end
end

local function keys()
    local map = vim.keymap.set

    -- Search and jump. These mirror the sway bindings, which are on Ctrl.
    map("n", "<C-p>", function() require("shycode.pick").files() end, { desc = "files" })
    map("n", "<C-g>", function() require("shycode.pick").grep() end, { desc = "workspace search" })

    -- Ctrl+S saves everywhere; the shell disables XOFF so it arrives (see
    -- shell/shy.zsh). Ctrl+Z / Ctrl+Y undo and redo, as in every other editor.
    map({ "n", "v" }, "<C-s>", "<cmd>write<cr>", { desc = "save" })
    map("i", "<C-s>", "<C-o><cmd>write<cr>")
    map("n", "<C-z>", "u")
    map("n", "<C-y>", "<C-r>")

    -- The agent, in a terminal split of the current editor.
    map("n", "<C-t>", function() require("shycode.agent").open() end, { desc = "agent" })

    -- Terminal buffers: Esc leaves terminal mode, as in most terminals.
    map("t", "<Esc>", "<C-\\><C-n>")

    -- Tab accepts the LSP selection first, then AI ghost text, or indents.
    -- This cannot be an `expr` mapping because accepting changes the buffer.
    map("i", "<Tab>", function()
        if vim.fn.pumvisible() == 1 then
            local keys = vim.fn.complete_info({ "selected" }).selected == -1 and "<C-n><C-y>" or "<C-y>"
            vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "n", false)
            return
        end
        if require("shycode.complete").accept() then
            return
        end
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Tab>", true, false, true), "n", false)
    end)
end

local function lsp()
    local function server()
        local found = vim.fn.exepath("shyc-lsp")
        if found ~= "" then
            return found
        end
        local fallback = vim.env.HOME .. "/.local/bin/shyc-lsp"
        if vim.fn.executable(fallback) == 1 then
            return fallback
        end
        return "shyc-lsp"
    end

    vim.lsp.config("shyc", {
        cmd = { server() },
        filetypes = { "shyc" },
        root_markers = { ".git", "Makefile", "Cargo.toml" },
        settings = { shyc = { diagnostics_enabled = true } },
    })
    vim.lsp.enable("shyc")

    vim.diagnostic.config({
        virtual_text = { prefix = "●", spacing = 2 },
        severity_sort = true,
        update_in_insert = false,
        underline = true,
    })

    vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
            local b = args.buf
            local map = function(lhs, rhs)
                vim.keymap.set("n", lhs, rhs, { buffer = b, silent = true })
            end
            map("gd", vim.lsp.buf.definition)
            map("<F12>", vim.lsp.buf.definition)
            map("K", vim.lsp.buf.hover)
            map("<F2>", vim.lsp.buf.document_symbol)
            vim.keymap.set("i", "<C-Space>", vim.lsp.completion.get,
                { buffer = b, silent = true, desc = "LSP completion" })
            map("<F8>", function() vim.diagnostic.jump({ count = 1 }) end)
            map("<S-F8>", function() vim.diagnostic.jump({ count = -1 }) end)

            local client = vim.lsp.get_client_by_id(args.data.client_id)
            if client and client:supports_method("textDocument/completion") then
                -- Use the server's '.', ':' and '>' triggers for member lists.
                vim.lsp.completion.enable(true, client.id, b, { autotrigger = true })
            end
        end,
    })
end

local function autocmds()
    -- sway's Ctrl+x kills the window, which would throw away unsaved work.
    -- Saving when the window loses focus makes that safe without an autosave
    -- timer: nothing is written while the editor is being typed in.
    vim.api.nvim_create_autocmd("FocusLost", {
        callback = function()
            if vim.bo.modified and vim.bo.buftype == "" and vim.api.nvim_buf_get_name(0) ~= "" then
                vim.cmd("silent! update")
            end
        end,
    })

    vim.api.nvim_create_autocmd("FileType", {
        pattern = { "shyc", "shyasm" },
        callback = function()
            vim.bo.commentstring = "// %s"
            vim.bo.expandtab = true
            vim.bo.shiftwidth = 4
            vim.bo.tabstop = 4
        end,
    })

    vim.api.nvim_create_autocmd("FileType", {
        pattern = "markdown",
        callback = function()
            vim.opt_local.wrap = true
            vim.opt_local.linebreak = true
            vim.opt_local.breakindent = true
        end,
    })
end

function M.setup()
    palette()
    options()
    keys()
    lsp()
    autocmds()

    -- Loaded eagerly because it owns the autocmds that turn typing into a
    -- completion request; loading it lazily would mean the first request only
    -- happens after the user presses Tab.
    require("shycode.complete")

    vim.api.nvim_create_user_command("Agent", function()
        require("shycode.agent").open()
    end, { desc = "open the coding agent in a terminal split" })

    vim.api.nvim_create_user_command("ShyComplete", function()
        require("shycode.complete").toggle()
    end, { desc = "toggle AI ghost text" })
end

return M
