grammar Himark;

query    : universe+ EOF ;
universe : LBRACE (member (COMMA member)*)? RBRACE ;

member
    : CHAR RANGE CHAR   # RangeMember
    | face RANGE        # FinalMember
    | BANG universe     # SubtractMember
    | factor+           # FactorsMember
    | face              # FaceMember
    ;

// A factor sequence is one member: a single brace group is a fold, a lone `&`
// is the bare self-reference, two or more factors are a product.
factor : universe | AMP ;

face : (CHAR | DOT | ESC)+ ;

LBRACE : '{' ;
RBRACE : '}' ;
COMMA  : ',' ;
BANG   : '!' ;
AMP    : '&' ;
RANGE  : '..' ;
DOT    : '.' ;
// A `//` line comment runs to end of line
COMMENT : '//' ~[\r\n]* ('\r'? '\n')? -> skip ;
ESC    : '\\' . ;
CHAR   : ~[{},!.\\&] ;
