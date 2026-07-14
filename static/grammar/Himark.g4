grammar Himark;

query    : universe+ EOF ;
universe : LBRACE (member (COMMA member)*)? RBRACE ;

member
    : CHAR RANGE CHAR   # RangeMember
    | face RANGE        # FinalMember
    | BANG universe     # SubtractMember
    | universe          # FoldMember
    | face              # FaceMember
    ;

face : (CHAR | DOT | ESC)+ ;

LBRACE : '{' ;
RBRACE : '}' ;
COMMA  : ',' ;
BANG   : '!' ;
RANGE  : '..' ;
DOT    : '.' ;
// A `//` line comment runs to end of line
COMMENT : '//' ~[\r\n]* ('\r'? '\n')? -> skip ;
ESC    : '\\' . ;
CHAR   : ~[{},!.\\] ;
