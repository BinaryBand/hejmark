grammar Himark;

query    : universe+ EOF ;
universe : LBRACE (member (COMMA member)*)? RBRACE ;

member
    : CHAR RANGE CHAR   # RangeMember
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
ESC    : '\\' . ;
CHAR   : ~[{},!.\\] ;
