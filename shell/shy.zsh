# Sourced from ~/.zshrc by install.sh.
#
# Everything the profile needs from the shell lives here: the editor is
# Neovim under both names, the file manager and archive tool are one letter,
# and Ctrl+S reaches the editor instead of freezing the terminal.

# Without this, Ctrl+S is software flow control (XOFF) and never reaches the
# editor. Ctrl+Q would be the resume key; nothing in the profile needs it.
stty -ixon 2>/dev/null

export EDITOR=nvim
export VISUAL=nvim
export PAGER=less
export MANPAGER='less -R'

# Plain vim is a real editor on this machine, but the profile standardises on
# Neovim; the vimrc installed alongside keeps the two behaving the same.
alias vim=nvim
alias vi=nvim
alias f=lf
alias g=rg

# `x` may already be an alias for an `extract` command that this machine does
# not have; the profile's extractor replaces it.
unalias x 2>/dev/null
x() {
    command shy-extract "$@"
}

# Secrets for the AI completion. The file is chmod 600 and never committed.
if [ -r "$HOME/.config/shy-code/llm.env" ]; then
    set -a
    . "$HOME/.config/shy-code/llm.env"
    set +a
    # The generic root is for chat completions; DSH uses the same variable for
    # its Messages API and must use its own /anthropic default instead.
    if [ "${DEEPSEEK_BASE_URL:-}" = "https://api.deepseek.com" ]; then
        unset DEEPSEEK_BASE_URL
    fi
fi
