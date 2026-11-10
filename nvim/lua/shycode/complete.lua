-- Inline AI completion, the Continue-style ghost text: after you stop typing
-- for a moment, a suggestion appears at the cursor and Tab accepts it.
--
-- Battery rules, in order of importance:
--   * the 700 ms debounce means a request is sent only when typing stops;
--   * only one request is in flight; a new keystroke cancels the old one;
--   * reasoning_effort=none keeps the answer to a handful of tokens, because
--     deepseek-flash otherwise spends the whole budget thinking and returns
--     nothing (measured: 24 reasoning tokens, empty content);
--   * the answer is shown as virtual text, so no buffer is modified until you
--     accept, and nothing is written to disk.
--
-- Features:
--   * Language detection: sends language-specific hints to AI for better context
--   * LSP integration for ShyC/C: queries LSP for type info and available symbols
--     to enrich the completion context with semantic information

local M = {}

local uv = vim.uv or vim.loop
local ns = vim.api.nvim_create_namespace("shycode-complete")
local timer = uv.new_timer()

local conf -- { key, base, model }
local job
local shown -- { text, buf, row, col }
local last_ctx
local enabled = true

-- Cache for frequently used information across edits
local typedef_cache = {}  -- name -> { def, timestamp }
local cache_ttl = 300000  -- 5 minutes in milliseconds

local CLEAN = "You are an inline code completion engine in a text editor. " ..
    "Continue the code at the cursor. Reply with only the characters to insert: " ..
    "no markdown, no code fences, no explanation, no repetition of existing text. " ..
    "Stop at the end of the line."

-- Language-specific completion hints for better context
local LANG_HINTS = {
    c = "Use ShyC syntax (arrow syntax a->b for pointers, use statements for imports).",
    shyc = "Use ShyC syntax (arrow syntax a->b for pointers, use statements for imports, struct/enum/union types).",
    shyasm = "Use ShyC assembly syntax.",
    python = "Use Python 3 syntax with type hints where appropriate.",
    lua = "Use Lua syntax (pairs, ipairs, local variables).",
    javascript = "Use modern JavaScript (ES6+) with const/let.",
    typescript = "Use TypeScript with type annotations.",
    rust = "Use Rust syntax with ownership and borrowing.",
    go = "Use Go syntax with proper error handling.",
}

-- Cache management functions
local function cache_get(key)
    local cached = typedef_cache[key]
    if cached then
        local age = vim.fn.localtime() * 1000 - cached.timestamp
        if age < cache_ttl then
            return cached.value
        end
        typedef_cache[key] = nil
    end
    return nil
end

local function cache_set(key, value)
    typedef_cache[key] = {
        value = value,
        timestamp = vim.fn.localtime() * 1000
    }
end

local function cache_clear()
    typedef_cache = {}
end

local function load_env()
    if conf then
        return conf
    end
    conf = {
        key = vim.env.DEEPSEEK_API_KEY,
        base = vim.env.DEEPSEEK_BASE_URL or "https://api.deepseek.com",
        model = vim.env.DEEPSEEK_MODEL or "deepseek-flash",
    }
    local file = vim.env.HOME .. "/.config/shy-code/llm.env"
    if vim.fn.filereadable(file) == 1 then
        for _, line in ipairs(vim.fn.readfile(file)) do
            local k, v = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
            if k == "DEEPSEEK_API_KEY" and (conf.key == nil or conf.key == "") then
                conf.key = v
            elseif k == "DEEPSEEK_BASE_URL" and vim.env.DEEPSEEK_BASE_URL == nil then
                conf.base = v
            elseif k == "DEEPSEEK_MODEL" and vim.env.DEEPSEEK_MODEL == nil then
                conf.model = v
            end
        end
    end
    return conf
end

local function clear()
    if shown and vim.api.nvim_buf_is_valid(shown.buf) then
        vim.api.nvim_buf_clear_namespace(shown.buf, ns, 0, -1)
    end
    shown = nil
end

-- The model likes to answer with a fence or a paragraph. Keep the first line
-- and drop the decoration.
local function clean(text)
    if type(text) ~= "string" then
        return ""
    end
    text = text:gsub("^```[%w]*\n?", "")
    text = text:gsub("```%s*$", "")
    text = text:gsub("^\r?\n+", "")
    text = text:match("^[^\r\n]*") or ""
    return (text:gsub("%s+$", ""))
end

local function show(text)
    if text == "" or vim.fn.mode() ~= "i" or vim.fn.pumvisible() == 1 then
        return
    end
    local buf = vim.api.nvim_get_current_buf()
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    local ok = pcall(vim.api.nvim_buf_set_extmark, buf, ns, row - 1, col, {
        virt_text = { { text, "Comment" } },
        virt_text_pos = "inline",
        hl_mode = "combine",
    })
    if ok then
        shown = { text = text, buf = buf, row = row, col = col }
    end
end

-- ------------------------------------------------------------ context files
--
-- ShyC imports two ways: `#include <x.h>` and `use a::b::*;`. The bodies of
-- those files are what make a completion useful (a struct's fields, a std
-- type's shape), so they are read once and put in their own message.
--
-- They go *before* the editable context on purpose: the provider caches the
-- prompt prefix, so an unchanged header block is billed at the cached rate on
-- every keystroke. The block is rebuilt only when the include list changes or
-- the file is written, never per keystroke.

local sources = {} -- file -> { key, block }
local libshy_dir_cached

local MAX_SOURCE_LINES = 120
local MAX_SOURCE_CHARS = 12000
local MAX_SCAN_LINES = 200

local function libshy_dir()
    if libshy_dir_cached ~= nil then
        return libshy_dir_cached
    end
    libshy_dir_cached = false
    local home = vim.env.HOME
    for _, conf in ipairs({ home .. "/.shycserver/config.toml", home .. "/.shycc.toml" }) do
        if vim.fn.filereadable(conf) == 1 then
            for _, line in ipairs(vim.fn.readfile(conf)) do
                local path = line:match('^%s*libshy_path%s*=%s*"(.-)"')
                    or line:match('^%s*shylib%s*=%s*"(.-)"')
                if path and vim.fn.isdirectory(path) == 1 then
                    libshy_dir_cached = path
                    return path
                end
            end
        end
    end
    return libshy_dir_cached
end

-- Same search order as the compiler, reduced to the directories that matter
-- for reading a header: the file's own directory, the libshy layers, the
-- project root.
local function search_dirs(file)
    local dirs, seen = {}, {}

    local function push(dir)
        if dir and dir ~= "" and not seen[dir] and vim.fn.isdirectory(dir) == 1 then
            seen[dir] = true
            dirs[#dirs + 1] = dir
        end
    end

    push(vim.fn.fnamemodify(file, ":h"))
    local root = libshy_dir()
    if root then
        push(root .. "/c")
        push(root)
        push(root .. "/include")
        push(vim.fn.fnamemodify(root, ":h") .. "/shyc/include")
    end
    push(vim.fn.getcwd())
    return dirs
end

local function resolve(name, dirs)
    for _, dir in ipairs(dirs) do
        local path = dir .. "/" .. name
        if vim.fn.filereadable(path) == 1 then
            return path
        end
    end
end

local function include_key(lines)
    local key = {}
    for _, line in ipairs(lines) do
        local inc = line:match('^%s*#%s*include%s*[<"]([^>"]+)[>"]')
        local use = line:match("^%s*use%s+([%w_:]+)")
        if inc then
            key[#key + 1] = "i:" .. inc
        end
        if use then
            key[#key + 1] = "u:" .. use
        end
    end
    return table.concat(key, "|")
end

local function build_block(lines, file)
    local dirs = search_dirs(file)
    local local_dirs = { vim.fn.fnamemodify(file, ":h") }
    local paths, seen, budget = {}, {}, MAX_SOURCE_CHARS

    local function want(path)
        if path and not seen[path] then
            seen[path] = true
            paths[#paths + 1] = path
        end
    end

    for _, line in ipairs(lines) do
        local open, name = line:match('^%s*#%s*include%s*([<"])([^>"]+)[>"]')
        if open then
            if open == '"' then
                want(resolve(name, local_dirs))
            end
            want(resolve(name, dirs))
        else
            local use = line:match("^%s*use%s+([%w_:]+)")
            if use then
                local segments = vim.split(use, "::", { plain = true })
                table.remove(segments) -- the imported item, or '*'
                if #segments > 0 then
                    local suffix = segments[1] == "c" and ".h" or ".shyh"
                    want(resolve(table.concat(segments, "/") .. suffix, dirs))
                end
            end
        end
    end

    local parts = {}
    for _, path in ipairs(paths) do
        local text = table.concat(vim.fn.readfile(path, "", MAX_SOURCE_LINES), "\n")
        if text ~= "" then
            if #text > budget then
                text = text:sub(1, budget)
            end
            parts[#parts + 1] = ("--- %s ---\n%s"):format(path, text)
            budget = budget - #text
            if budget <= 0 then
                break
            end
        end
    end
    return table.concat(parts, "\n\n")
end

local function sources_for(file)
    local count = math.min(MAX_SCAN_LINES, vim.api.nvim_buf_line_count(0))
    local lines = vim.api.nvim_buf_get_lines(0, 0, count, false)
    local key = include_key(lines)
    local cached = sources[file]
    if cached and cached.key == key then
        return cached.block
    end
    local block = build_block(lines, file)
    sources[file] = { key = key, block = block }
    return block
end

-- Get LSP hover info and available completions for context enrichment
local function lsp_context()
    local buf = vim.api.nvim_get_current_buf()
    if not vim.api.nvim_buf_is_valid(buf) then
        return nil
    end
    
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local pos = { line = row - 1, character = col }
    
    local context_info = ""
    local ok_hover, hover_result = pcall(function()
        return vim.lsp.buf_request_sync(buf, "textDocument/hover", {
            textDocument = vim.lsp.util.make_text_document_uri(buf),
            position = pos,
        }, 200)
    end)
    
    if ok_hover and hover_result then
        for _, res in pairs(hover_result) do
            if res and res.result and res.result.contents then
                local contents = res.result.contents
                local text = type(contents) == "string" and contents 
                    or (contents.value and contents.value)
                    or ""
                if text ~= "" and type(text) == "string" then
                    -- Clean up markdown formatting if present
                    text = text:gsub("```[%w]*\n?", ""):gsub("```%s*$", ""):match("^[^\n]*") or ""
                    if text ~= "" then
                        context_info = context_info .. "Hover: " .. text .. "\n"
                    end
                end
            end
        end
    end
    
    -- Try to get available completions from LSP
    local ok_comp, comp_result = pcall(function()
        return vim.lsp.buf_request_sync(buf, "textDocument/completion", {
            textDocument = vim.lsp.util.make_text_document_uri(buf),
            position = pos,
        }, 200)
    end)
    
    if ok_comp and comp_result then
        local items = {}
        for _, res in pairs(comp_result) do
            if res and res.result then
                local completions = res.result.items or res.result
                if type(completions) == "table" then
                    for i, item in ipairs(completions) do
                        if i <= 10 then  -- Limit to 10 completions to save context
                            local label = item.label or item.insertText or ""
                            if label ~= "" and type(label) == "string" then
                                table.insert(items, label)
                            end
                        end
                    end
                end
            end
        end
        if #items > 0 then
            context_info = context_info .. "Available: " .. table.concat(items, ", ") .. "\n"
        end
    end
    
    return context_info ~= "" and context_info or nil
end

-- Analyze ShyC-specific context to provide better guidance
local function analyze_shyc_context()
    local buf = vim.api.nvim_get_current_buf()
    local row = vim.api.nvim_win_get_cursor(0)[1]
    local line = vim.api.nvim_get_current_line()
    
    -- Context type detection
    if line:match("->%s*$") then
        return "struct_member", "Completing struct/union member after pointer access"
    end
    
    if line:match("%.%s*$") then
        return "struct_field", "Completing struct/union field after direct access"
    end
    
    if line:match("^%s*use%s+[%w_:]*%s*$") then
        return "import", "Completing import path (use statement)"
    end
    
    if line:match("%(") and not line:match("%)") then
        return "param", "Completing function parameter or argument"
    end
    
    if line:match("::%s*$") then
        return "namespace", "Completing namespace or module access"
    end
    
    if line:match("%[%s*$") then
        return "subscript", "Completing array/slice subscript"
    end
    
    return "general", "General code completion"
end

-- Build ShyC-specific system message based on context
local function get_shyc_hint(ctx_type)
    local hints = {
        struct_member = "Suggest struct/union member names that could follow this pointer access.",
        struct_field = "Suggest struct/union field names for direct access.",
        import = "Suggest module or symbol names for the use statement. Focus on public symbols.",
        param = "Suggest appropriate types or values for function parameters.",
        namespace = "Suggest namespace, module, or type names.",
        subscript = "Suggest valid array indices or slice operations.",
        general = "Continue the ShyC code naturally.",
    }
    return hints[ctx_type] or "Continue the code."
end

-- Get language-specific hint based on filetype
local function get_lang_hint(filetype)
    return LANG_HINTS[filetype] or "Use the appropriate syntax for " .. (filetype or "this language") .. "."
end

local function request(ctx, files, on_text, filetype)
    local c = load_env()
    if not c.key or c.key == "" then
        return
    end

    if job then
        vim.fn.jobstop(job)
        job = nil
    end

    -- Fixed system message, then the stable header block, then the changing
    -- excerpt: the longest possible prefix stays identical between requests.
    local system_msg = CLEAN
    local lang_hint = get_lang_hint(filetype)
    if lang_hint then
        system_msg = system_msg .. " " .. lang_hint
    end
    
    -- Add ShyC-specific context hint if applicable
    if filetype == "shyc" or filetype == "c" then
        local ctx_type, ctx_desc = analyze_shyc_context()
        local shyc_hint = get_shyc_hint(ctx_type)
        system_msg = system_msg .. " " .. shyc_hint
    end
    
    local messages = { { role = "system", content = system_msg } }
    
    -- Add LSP context for ShyC files
    if filetype == "shyc" or filetype == "c" then
        local lsp_info = lsp_context()
        if lsp_info then
            messages[#messages + 1] = { role = "system", content = "Type context from LSP:\n" .. lsp_info }
        end
    end
    
    if files and files ~= "" then
        messages[#messages + 1] = { role = "system", content = files }
    end
    messages[#messages + 1] = { role = "user", content = ctx }

    local body = vim.json.encode({
        model = c.model,
        temperature = 0,
        max_tokens = 48,
        reasoning_effort = "none",
        messages = messages,
    })

    local out = {}
    job = vim.fn.jobstart({
        "curl", "-sS", "--max-time", "6",
        "-H", "Content-Type: application/json",
        "-H", "Authorization: Bearer " .. c.key,
        "-d", body,
        c.base .. "/chat/completions",
    }, {
        stdout_buffered = true,
        on_stdout = function(_, data)
            if data then
                out = data
            end
        end,
        on_exit = function(_, code)
            job = nil
            if code ~= 0 then
                return
            end
            local ok, resp = pcall(vim.json.decode, table.concat(out, "\n"))
            if not ok or type(resp) ~= "table" or not resp.choices then
                return
            end
            local msg = resp.choices[1] and resp.choices[1].message
            on_text(clean(msg and msg.content))
        end,
    })
end

local function context()
    local buf = vim.api.nvim_get_current_buf()
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local from = math.max(0, row - 31)
    local lines = vim.api.nvim_buf_get_lines(buf, from, row, false)
    if #lines == 0 then
        return nil
    end
    lines[#lines] = lines[#lines]:sub(1, col)
    local path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":~:.")
    return string.format("File: %s\nLanguage: %s\n\n%s",
        path, vim.bo[buf].filetype, table.concat(lines, "\n"))
end

function M.suggest()
    if not enabled or vim.fn.mode() ~= "i" or vim.fn.pumvisible() == 1 then
        return
    end
    local buf = vim.api.nvim_get_current_buf()
    if vim.api.nvim_buf_get_name(buf) == "" or vim.bo[buf].buftype ~= "" then
        return
    end
    if vim.api.nvim_buf_line_count(buf) > 4000 then
        return
    end
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local line = vim.api.nvim_get_current_line()
    if line == "" or (col < 1 and row == 1) then
        return
    end

    local ctx = context()
    if not ctx or ctx == last_ctx then
        return
    end
    last_ctx = ctx
    local filetype = vim.bo[buf].filetype
    request(ctx, sources_for(vim.api.nvim_buf_get_name(buf)), show, filetype)
end

function M.schedule()
    timer:stop()
    timer:start(700, 0, vim.schedule_wrap(M.suggest))
end

-- Tab calls this first: a visible suggestion is inserted, otherwise Tab is
-- left alone. The LSP popup keeps its own Tab behaviour.
function M.accept()
    if not shown or vim.fn.pumvisible() == 1 then
        return false
    end
    local buf = vim.api.nvim_get_current_buf()
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    if shown.buf ~= buf or shown.row ~= row or shown.col ~= col then
        clear()
        return false
    end
    local text = shown.text
    clear()
    vim.api.nvim_put({ text }, "c", false, true)
    return true
end

function M.toggle()
    enabled = not enabled
    if not enabled then
        timer:stop()
        if job then
            vim.fn.jobstop(job)
            job = nil
        end
        clear()
        last_ctx = nil
    end
    vim.notify("AI ghost text " .. (enabled and "on" or "off"))
end

vim.api.nvim_create_autocmd("BufWritePost", {
    callback = function(args)
        sources[vim.api.nvim_buf_get_name(args.buf)] = nil
        -- Clear cache when file is saved to ensure fresh data
        if vim.bo[args.buf].filetype == "shyc" or vim.bo[args.buf].filetype == "c" then
            cache_clear()
        end
    end,
})

vim.api.nvim_create_autocmd("TextChangedI", {
    callback = function()
        M.schedule()
    end,
})

vim.api.nvim_create_autocmd("CursorMovedI", {
    callback = function()
        clear()
    end,
})

vim.api.nvim_create_autocmd({ "InsertLeave", "BufLeave" }, {
    callback = function()
        timer:stop()
        if job then
            vim.fn.jobstop(job)
            job = nil
        end
        clear()
        last_ctx = nil
    end,
})

return M
