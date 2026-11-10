" ShyC highlighting for Vim and Neovim.
"
" This is the cheap half: regex highlighting of what is on screen, done by the
" editor's own syntax engine. The accurate half is shyc-lsp's semantic tokens,
" which colour identifiers by meaning once the server attaches. Together they
" cost a fraction of a tree-sitter parse per keystroke.
"
" Order matters: later definitions win at the same position, so the specific
" patterns (strings, comments) come after the broad ones (keywords), and the
" function-call pattern comes before the keyword list so `if (` stays a keyword.

if exists("b:current_syntax")
  finish
endif

syn case match

" Names introduced by a declaration.
syn match   shycFuncName  "\<fn\s\+\zs\h\w*"
syn match   shycTypeName  "\<\%(struct\|enum\|union\|trait\)\s\+\zs\h\w*"
syn match   shycFuncCall  "\<\h\w*\ze\s*("
syn match   shycAttr      "#!\[[^\]]*\]"

syn match   shycNumber    "\<\%(0[xX][0-9a-fA-F_]\+\|\d[0-9_]*\)\%([uUlL]\+\|\.\d\+\)\?\>"
syn match   shycOperator  "[=+\-*/%<>!&|^~?:]"

" Keywords and types.
syn keyword shycKeyword auto break case const continue default do else enum
syn keyword shycKeyword extern for goto if inline register restrict return
syn keyword shycKeyword sizeof static struct switch typedef union volatile
syn keyword shycKeyword while fn impl trait pub mut use defer as asm
syn keyword shycKeyword _Alignas _Alignof _Atomic _Bool _Complex _Generic
syn keyword shycKeyword _Imaginary _Noreturn _Static_assert _Thread_local
syn keyword shycKeyword alignof alignas typeof __typeof __typeof__
syn keyword shycKeyword __attribute __attribute__ __declspec __inline __inline__
syn keyword shycKeyword __restrict __restrict__ __thread
syn keyword shycType    void char short int long float double signed unsigned
syn keyword shycType    bool i8 i16 i32 i64 u8 u16 u32 u64 isize usize f32 f64
syn keyword shycType    size_t ptrdiff_t
syn keyword shycConstant true false null NULL

" Preprocessor and attributes.
syn match   shycInclude   "^\s*#\s*include\s\+[<\"][^>\"]*[>\"]"
syn match   shycPreProc   "^\s*#\s*\w\+"
syn match   shycDefine    "^\s*#\s*define\s\+\zs\h\w*"

" Literals.
syn region  shycString    start=+"+ skip=+\\"+ end=+"+ contains=shycEscape
syn region  shycChar      start=+'+ skip=+\\'+ end=+'+ contains=shycEscape
syn match   shycEscape    "\\." contained

" Comments last: they must beat keywords and calls inside the comment body.
syn keyword shycTodo      contained TODO FIXME XXX NOTE
syn region  shycComment   start="//" end="$" contains=shycTodo
syn region  shycComment   start="/\*" end="\*/" contains=shycTodo

hi def link shycComment   Comment
hi def link shycTodo      Todo
hi def link shycString    String
hi def link shycChar      Character
hi def link shycEscape    SpecialChar
hi def link shycNumber    Number
hi def link shycKeyword   Keyword
hi def link shycType      Type
hi def link shycConstant  Constant
hi def link shycPreProc   PreProc
hi def link shycInclude   Include
hi def link shycDefine    Define
hi def link shycAttr      PreProc
hi def link shycFuncName  Function
hi def link shycFuncCall  Function
hi def link shycTypeName  Structure
hi def link shycOperator  Operator

let b:current_syntax = "shyc"
