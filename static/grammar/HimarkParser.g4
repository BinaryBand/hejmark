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
    | IDENT param* WALRUS expr    # DefDecl
    ;

// A parameter is an identifier or an identifier pair (`lo..hi`); a lone
// numeral argument binds a pair parameter as the degenerate pair `n..n`.
param : IDENT (RANGE IDENT)? ;

// An emit statement: steps joined by `=>`, each a query or a template. The
// optional newlines before an arrow are the continuation-line rule.
statement : step (NL* ARROW step)* ;

// A contracting statement `query <=>[@m] template`: the one iterated form.
// The measure is a declared name riding the arrow the way a pipeline rides a
// unit; the bracket lexes in ARGS mode, so the reference is one ARG token.
contract : expr NL* IARROW LBRACK A_WS? ARG A_WS? RBRACK template ;

step
    : expr        # QueryStep
    | template    # TemplateStep
    ;

// Adjacency is the product; a lone unit is the singleton case.
expr : unit+ ;

unit : base (CARET exponent)? pipeline? ;

base
    : universe    # UniverseBase
    | REF         # ReferenceBase
    | USCORE      # OperandBase
    ;

// `A^n`: the exponent is a numeral, a numeral parameter, or a braced
// parameter (`fill^{w'}`). Inside braces the operand lexes as a face.
exponent
    : NUM
    | IDENT
    | face
    | universe
    ;

// The modifier pipeline `A[f x g y]`: stages left to right. Stage names and
// arguments lex alike; binding splits the flat item list by each
// definition's arity.
pipeline : LBRACK A_WS? pipeItem (A_WS pipeItem)* A_WS? RBRACK ;

pipeItem : pipeArg (RANGE pipeArg?)? ;

// An argument, or a back-reference standing as one (`where 0..$2`). A trailing
// `..` with no second argument is the open pair (`where 0..`).
pipeArg : ARG | CAPTURE ;

universe : LBRACE (member (COMMA member)*)? RBRACE ;

member
    : face RANGE face      # RangeMember
    | face RANGE           # FinalMember
    | REF RANGE valueBound? # ValueMember
    | BANG universe         # SubtractMember
    | segment+              # SegmentsMember
    ;

// The value family `@lo..hi`: the head's value line cut by value. The low bound
// rides the REF sigil (`@0`, or `@lo` naming a numeral parameter); the high
// bound is a numeral, a parameter, or a back-reference standing as one. An
// absent bound is the open case `@lo..`: the whole value tail from `lo`.
valueBound : face | CAPTURE ;

// One adjacent piece of a member: a brace group, the closure token, a
// reference, the operand token, or a bare face. `@name face` may be an
// application (`!{@shorter w}`) or an adjacency -- binding decides by arity.
segment
    : base (CARET exponent)? pipeline?
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
