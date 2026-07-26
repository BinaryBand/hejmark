lexer grammar HimarkLexer;

// ---------------------------------------------------------------------------
// DEFAULT mode -- the script level: declarations and emit statements, one per
// logical line. Faces never appear here, so keywords and identifiers lex
// cleanly; braces, brackets, and quotes push the modes below. Whitespace is
// insignificant out here (skipped); brackets and quotes keep it to their own
// rules, but inside braces it is a literal face character (see BRACES). Newlines
// separate lines out here; a bracket or quote spanning physical lines stays one
// statement (a brace spanning them now embeds literal newlines, so don't).
// ---------------------------------------------------------------------------

UNI      : 'uni' ;
DEF      : 'def' ;
SENTINEL : 'sentinel' ;
ARROW  : '=>' ;
// The contracting arrow: its statement re-runs until a pass leaves the
// document unchanged -- a bare fixpoint.
IARROW : '<=>' ;
EQ     : '=' ;
RANGE  : '..' ;
USCORE : '_' ;
CARET  : '^' ;

// `@name` splices a declaration; bare `@` and `@0` are the reserved names
// (the pipeline head and its zero entry). Lexed as one token so an adjacent
// face or identifier never merges into the name.
REF : '@' [a-zA-Z0-9']* ;

IDENT : [a-zA-Z] [a-zA-Z0-9']* ;
NUM   : [0-9]+ ;

LBRACE    : '{' -> pushMode(BRACES) ;
LBRACK    : '[' -> pushMode(ARGS) ;
TMPL_OPEN : '"' -> pushMode(TMPL) ;

// A `//` comment runs to end of line at depth 0 only (`{http://x}` stays a
// face); the newline after it still counts as a line break.
COMMENT : '//' ~[\r\n]* -> skip ;
NL      : '\r'? '\n' ;
WS      : [ \t]+ -> skip ;

// ---------------------------------------------------------------------------
// BRACES mode -- inside `{...}`, where faces live. Every structural character
// is carved out of the face alphabet (spell it literally with a `\` escape);
// everything else -- whitespace, newlines, and parentheses included -- is a
// literal face character, so `{cat dog}` is one face and members are separated
// by `,` alone (`{cat,dog}`). A definition is applied only through the pipeline
// `A[f x]`, never by juxtaposition -- a space between a name and a word is content.
// ---------------------------------------------------------------------------

mode BRACES;

B_LBRACE : '{'  -> type(LBRACE), pushMode(BRACES) ;
RBRACE   : '}'  -> popMode ;
COMMA    : ',' ;
BANG     : '!' ;
AMP      : '&' ;
B_RANGE  : '..' -> type(RANGE) ;
DOT      : '.' ;
B_REF    : '@' ~[{}()[\],!.\\&@_^$" \t\r\n]* -> type(REF) ;
B_USCORE : '_'  -> type(USCORE) ;
B_CARET  : '^'  -> type(CARET) ;
B_LBRACK : '['  -> type(LBRACK), pushMode(ARGS) ;
// A back-reference `$k` standing where a universe stands: factor k of the
// same query, as it hit. Only the factor family enters a pattern -- `$` and
// `$0` are the emitter's -- so a bare or zero read here stays a lex error.
B_CAPTURE : '$' [1-9] [0-9]* -> type(CAPTURE) ;
// A structural character spelled literally, or the two-dot sequence `\..`; the
// mnemonics `\n`/`\t`/`\r` ride the same backslash. A lone `.` is already a
// literal dot, so `\.` is not an escape, and every other `\x` has no reading --
// it fails to lex, which is what keeps the rest of the alphabet open.
ESC      : '\\' ( '..' | [nrt,{}[\]!&@_^$"\\] ) ;
CHAR     : ~[{}[\],!.\\&@_^$"] ;

// ---------------------------------------------------------------------------
// ARGS mode -- inside a pipeline bracket `[...]`.
// Stage/definition names and their arguments lex alike (binding splits the flat
// list by each definition's arity); `..` keeps its range reading, and a literal
// `.` `]` or space in an argument is escaped.
// ---------------------------------------------------------------------------

mode ARGS;

RBRACK  : ']'  -> popMode ;
A_RANGE : '..' -> type(RANGE) ;
// A lone `.` is a literal dot, as in a face (`..` is the range, `\..` the
// literal two dots); it lexes as its own token and the parser assembles it into
// the argument.
A_DOT   : '.'  -> type(DOT) ;
// Emitted, not skipped: whitespace separates pipeline items (`where 8..12 pad
// 1..2` is two items), so a stage's arguments never run into the next stage.
A_WS    : [ \t\r\n]+ ;
// A back-reference standing as an argument (`where 0..$2`). Listed before ARG
// so the exact spelling `$k` lexes as a read; anything longer stays an ARG.
A_CAPTURE : '$' [1-9] [0-9]* -> type(CAPTURE) ;
// One argument piece is one token. An argument's structural characters (its
// brackets, whitespace, and the range dots) are spelled literally with a `\`
// escape (`\..` the two dots); every other `\x` has no reading and fails to lex.
ARG     : (~[[\]. \t\r\n\\] | '\\' ( '..' | [[\] \t\r\n\\] ))+ ;

// ---------------------------------------------------------------------------
// TMPL mode -- inside a quoted template. Text is literal (whitespace and
// newlines included) until the closing quote; `{{` opens an interpolation,
// and a lone `{` is ordinary text.
// ---------------------------------------------------------------------------

mode TMPL;

TMPL_CLOSE  : '"'  -> popMode ;
MOUST_OPEN  : '{{' -> pushMode(INTERP) ;
// A template's structural characters (`"` `\` `{`) spelled literally, plus the
// mnemonics `\n`/`\t`/`\r`; every other `\x` has no reading and fails to lex.
TMPL_ESC    : '\\' ["\\{nrt] ;
TMPL_LBRACE : '{' ;
TMPL_TEXT   : ~["\\{]+ ;

// ---------------------------------------------------------------------------
// INTERP mode -- inside `{{ ... }}`: one read. A capture read (`$` the hit as
// it hit, `$0` its canonical face, `$1..$n` factor k of the hit as it hit) or
// a sentinel read (`@name` the face a `sentinel` declaration allocated). A
// factor read is 1-based and carries no leading zero, which is what keeps the
// canonical read `$0` unambiguous.
// ---------------------------------------------------------------------------

mode INTERP;

MOUST_CLOSE : '}}' -> popMode ;
CAPTURE     : '$' ('0' | [1-9] [0-9]*)? ;
I_REF       : '@' [a-zA-Z0-9']* -> type(REF) ;
I_WS        : [ \t]+ -> skip ;
