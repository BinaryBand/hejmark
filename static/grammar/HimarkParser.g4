parser grammar HimarkParser;

options {
    tokenVocab = HimarkLexer;
}

// A .hmk script: declarations and statements, one per logical line. The modes
// in HimarkLexer.g4 swallow newlines inside braces, brackets, and quotes, so
// a construct spanning physical lines stays one line here; a line whose first
// token is `=>` continues the statement above it (see `statement`).
script : NL* (line (NL+ line)* NL*)? EOF ;

line
    : declaration
    | contract
    | statement
    ;

declaration
    : UNI IDENT EQ expr           # UniDecl
    | SENTINEL IDENT              # SentinelDecl
    | DEF IDENT param* EQ expr    # DefDecl
    ;

// A parameter is an identifier or an identifier pair (`lo..hi`); a lone
// numeral argument binds a pair parameter as the degenerate pair `n..n`.
param : IDENT (RANGE IDENT)? ;

// An emit statement: steps joined by `=>`, each a query or a template. The
// optional newlines before an arrow are the continuation-line rule.
statement : step (NL* ARROW step)* ;

// A contracting statement `query <=> template`: the one iterated form. The pass
// re-runs to a fixpoint -- until it leaves the document unchanged.
contract : expr NL* IARROW template ;

step
    : expr        # QueryStep
    | template    # TemplateStep
    ;

// Adjacency is the product; a lone unit is the singleton case.
expr : unit+ ;

// Brackets chain: `A[f][g]` is `(A[f])[g]`, each bracket re-pointing the head
// to its left operand. One bracket's stages share a head (the fused pipeline).
unit : base (CARET exponent)? pipeline* ;

base
    : universe        # UniverseBase
    | REF             # ReferenceBase
    | USCORE          # OperandBase
    ;

// `A^x..y`: a closed count span, `A` unioned across the powers `x..y`. A lone
// `A^n` is the degenerate `A^n..n`; both counts are always written, so an open
// `A^x..` has no reading (unbounded repetition is closure's, `&`). Each count is
// a numeral, a numeral parameter, or a braced parameter (`fill^{w'}`); inside
// braces the operand lexes as a face.
exponent : exponentAtom (RANGE exponentAtom)? ;

exponentAtom
    : NUM
    | IDENT
    | face
    | universe
    ;

// One modifier bracket `[f x g y]`: stages left to right, sharing a head. Stage
// names and arguments lex alike; binding splits the flat item list by each
// definition's arity. A unit may carry several brackets, which chain.
pipeline : LBRACK A_WS? pipeItem (A_WS pipeItem)* A_WS? RBRACK ;

pipeItem : pipeArg (RANGE pipeArg)? ;

// An argument, or a back-reference standing as one (`where 0..$2`). A lone
// argument binds a pair parameter as the degenerate pair `n..n`; a pair writes
// both bounds -- there is no open pair, since `where 0..` has no reading.
// An argument assembles from its pieces (a bare `.` is a literal dot, as in a
// face), or a back-reference standing as one.
pipeArg : (ARG | DOT)+ | CAPTURE ;

universe : LBRACE (member (COMMA member)*)? RBRACE ;

member
    : face RANGE face      # RangeMember
    | REF RANGE valueBound  # ValueMember
    | BANG universe         # SubtractMember
    | segment+              # SegmentsMember
    ;

// The value family `@lo..hi`: the head's value line cut by value. The low bound
// rides the REF sigil (`@0`, or `@lo` naming a numeral parameter); the high
// bound is a numeral, a parameter, or a back-reference standing as one. Both
// bounds are always written -- there is no open cut, since `@lo..` has no
// reading; the degenerate `@0..0` is spelled as the bare splice `@0`.
valueBound : face | CAPTURE ;

// One adjacent piece of a member: a brace group, the closure token, a
// reference, the operand token, or a bare face. Adjacency is always a product;
// a definition is applied only through the modifier pipeline `A[f x]`, never by
// juxtaposition, since a space here is a literal face character.
segment
    : base (CARET exponent)? pipeline*
    | AMP
    | CAPTURE
    | face
    ;

face : (CHAR | DOT | ESC)+ ;

template : TMPL_OPEN part* TMPL_CLOSE ;

part
    : TMPL_TEXT      # TextPart
    | TMPL_ESC       # EscPart
    | TMPL_LBRACE    # LoneBracePart
    | interp         # InterpPart
    ;

// Each interpolation holds one read -- a capture or a sentinel -- and is its
// own branch.
interp : MOUST_OPEN (CAPTURE | REF) MOUST_CLOSE ;
