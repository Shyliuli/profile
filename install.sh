#!/bin/sh
# Install the ShyProject coding profile into $HOME.
#
# Run it from a normal terminal (it needs sudo for the packages). Re-running is
# safe: symlinks are replaced, and a real file or directory is moved aside only
# the first time, as <name>.before-shy-code.<timestamp>.

set -eu

here=$(cd "$(dirname "$0")" && pwd)
cfg=${XDG_CONFIG_HOME:-$HOME/.config}
bin=$HOME/.local/bin
stamp=$(date +%Y%m%d-%H%M%S)

packages=$(sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^$/d' "$here/packages.txt" | tr '\n' ' ')

echo "==> packages"
# shellcheck disable=SC2086
sudo pacman -S --needed --noconfirm $packages

echo "==> helpers in $bin"
mkdir -p "$bin"
for f in "$here"/bin/*; do
    chmod +x "$f"
    ln -sfn "$f" "$bin/$(basename "$f")"
done

backup() {
    [ -e "$1" ] || return 0
    [ -L "$1" ] && return 0
    mv "$1" "$1.before-shy-code.$stamp"
}

link() {
    mkdir -p "$(dirname "$2")"
    backup "$2"
    ln -sfn "$1" "$2"
}

echo "==> configs in $cfg"
link "$here/sway"      "$cfg/sway"
link "$here/kitty"     "$cfg/kitty"
link "$here/foot"      "$cfg/foot"
link "$here/nvim"      "$cfg/nvim"
link "$here/lf"        "$cfg/lf"
link "$here/fuzzel"    "$cfg/fuzzel"

# Plain Vim gets the same syntax and the same filetypes.
link "$here/vim/vimrc" "$HOME/.vimrc"
mkdir -p "$HOME/.vim/syntax" "$HOME/.vim/ftdetect"
ln -sfn "$here/nvim/syntax/shyc.vim"   "$HOME/.vim/syntax/shyc.vim"
ln -sfn "$here/nvim/syntax/shyasm.vim" "$HOME/.vim/syntax/shyasm.vim"
ln -sfn "$here/nvim/ftdetect/shyc.vim" "$HOME/.vim/ftdetect/shyc.vim"

echo "==> session environment"
mkdir -p "$cfg/environment.d"
cp "$here/environment.d/90-shycode.conf" "$cfg/environment.d/90-shycode.conf"

echo "==> screenshot directory"
mkdir -p "${XDG_PICTURES_DIR:-$HOME/图片}/Screenshots"

echo "==> secrets"
mkdir -p "$cfg/shy-code"
cp "$here/llm.env" "$cfg/shy-code/llm.env"
chmod 600 "$cfg/shy-code/llm.env"

echo "==> language server"
mkdir -p "$HOME/.shycserver"
repo=$(cd "$here/.." 2>/dev/null && pwd || true)
libshy=""
if [ -n "$repo" ] && [ -d "$repo/libshy/include" ]; then
    libshy=$repo/libshy
elif [ -r "$HOME/.shycc.toml" ]; then
    libshy=$(sed -n 's/^shylib *= *"\(.*\)"/\1/p' "$HOME/.shycc.toml" | head -1)
fi
if [ -n "$libshy" ]; then
    printf 'libshy_path = "%s"\n' "$libshy" > "$HOME/.shycserver/config.toml"
    echo "    libshy: $libshy"
else
    echo "    libshy: not found; set libshy_path in ~/.shycserver/config.toml"
fi

if [ -n "$repo" ] && [ -x "$repo/vscode-shyc/server/bin/shyc-lsp" ]; then
    ln -sfn "$repo/vscode-shyc/server/bin/shyc-lsp" "$bin/shyc-lsp"
    echo "    shyc-lsp: $repo/vscode-shyc/server/bin/shyc-lsp"
elif command -v shyc-lsp >/dev/null 2>&1; then
    echo "    shyc-lsp: $(command -v shyc-lsp)"
else
    echo "    shyc-lsp: not found; build it with 'cargo build --release' in vscode-shyc/server"
fi

echo "==> agent instructions"
# Codex reads its global instructions from $CODEX_HOME/AGENTS.md (~/.codex).
mkdir -p "$HOME/.codex"
backup "$HOME/.codex/AGENTS.md"
ln -sfn "$here/AGENTS.md" "$HOME/.codex/AGENTS.md"

echo "==> agent"
if command -v go >/dev/null 2>&1; then
    GOBIN="$bin" go install github.com/charmbracelet/crush@latest 2>/dev/null \
        && echo "    crush: $bin/crush" \
        || echo "    crush: go install failed"
else
    echo "    crush: no Go toolchain; install it and re-run"
fi

# Crush reads its provider from its own config file, so the key is copied
# there from the one place it is kept. 600: it is a secret.
set -a
. "$here/llm.env"
set +a
mkdir -p "$cfg/crush"
backup "$cfg/crush/crush.json"
cat > "$cfg/crush/crush.json" <<JSON
{
  "\$schema": "https://charm.land/crush.json",
  "providers": {
    "deepseek": {
      "type": "openai",
      "base_url": "$DEEPSEEK_BASE_URL/v1",
      "api_key": "$DEEPSEEK_API_KEY",
      "models": [
        { "id": "$DEEPSEEK_MODEL", "name": "DeepSeek Flash", "context_window": 1000000, "default_max_tokens": 32000, "can_reason": false }
      ]
    }
  },
  "models": {
    "large": { "provider": "deepseek", "model": "$DEEPSEEK_MODEL" },
    "small": { "provider": "deepseek", "model": "$DEEPSEEK_MODEL" }
  }
}
JSON
chmod 600 "$cfg/crush/crush.json"

echo "==> shell"
cp "$here/shell/shy.zsh" "$cfg/shy-code/shy.zsh"
if ! grep -q "shy-code/shy.zsh" "$HOME/.zshrc" 2>/dev/null; then
    printf '\n# ShyProject coding profile\n[ -r "%s/shy-code/shy.zsh" ] && . "%s/shy-code/shy.zsh"\n' \
        "$cfg" "$cfg" >> "$HOME/.zshrc"
fi

echo
echo "Done. Start the session by choosing 'sway' at the login screen, or run: sway"
echo "Undo: remove the symlinks in $cfg and restore *.before-shy-code.$stamp"
