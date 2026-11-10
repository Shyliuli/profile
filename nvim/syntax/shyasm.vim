" Shy assembly highlighting for Vim and Neovim.
"
" The grammar in the VS Code extension colours the first lowercase word of a
" line as a mnemonic; this does the same, then adds registers, numbers, labels,
" directives and the #![...] metadata block.

if exists("b:current_syntax")
  finish
endif

syn case match

syn match   shyasmMeta      "#!\[[^\]]*\]"
syn region  shyasmComment   start="//" end="$"
syn region  shyasmComment   start="/\*" end="\*/"

syn region  shyasmString    start=+"+ skip=+\\"+ end=+"+ contains=shyasmEscape
syn match   shyasmEscape    "\\." contained

syn match   shyasmNumber    "\<\%(0[xX][0-9a-fA-F]\+\|[01]\+[bB]\|\d\+\)\>"

" Registers, case-insensitively: ax, x8, pc, sp, m1..m4, status, ...
syn match   shyasmRegister  "\c\<\%([0-9a-f]x\|ax\|bx\|cx\|dx\|ex\|fx\|pc\|segs\|sp\|tm\|status\|trap\|m[1-4]\|rs\|exit\|epc\|cause\|ksp\|sege\)\>"

" A label is `name:` at the start of a line.
syn match   shyasmLabel     "^\s*\zs\h[\w.$]*\ze:"
syn match   shyasmDirective "^\s*\.\w\+"

" A mnemonic is the first word of the line, before the label rule can claim it.
syn match   shyasmMnemonic  "^\s*\zs[a-z][a-z0-9]*\>"

hi def link shyasmComment   Comment
hi def link shyasmString    String
hi def link shyasmEscape    SpecialChar
hi def link shyasmNumber    Number
hi def link shyasmRegister  Identifier
hi def link shyasmLabel     Label
hi def link shyasmDirective PreProc
hi def link shyasmMnemonic  Statement
hi def link shyasmMeta      PreProc

let b:current_syntax = "shyasm"
