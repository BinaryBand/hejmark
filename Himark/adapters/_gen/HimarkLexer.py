# Generated from grammar/Himark.g4 by ANTLR 4.13.2
from antlr4 import *
from io import StringIO
import sys
if sys.version_info[1] > 5:
    from typing import TextIO
else:
    from typing.io import TextIO


def serializedATN():
    return [
        4,0,8,35,6,-1,2,0,7,0,2,1,7,1,2,2,7,2,2,3,7,3,2,4,7,4,2,5,7,5,2,
        6,7,6,2,7,7,7,1,0,1,0,1,1,1,1,1,2,1,2,1,3,1,3,1,4,1,4,1,4,1,5,1,
        5,1,6,1,6,1,6,1,7,1,7,0,0,8,1,1,3,2,5,3,7,4,9,5,11,6,13,7,15,8,1,
        0,1,6,0,33,33,44,44,46,46,92,92,123,123,125,125,34,0,1,1,0,0,0,0,
        3,1,0,0,0,0,5,1,0,0,0,0,7,1,0,0,0,0,9,1,0,0,0,0,11,1,0,0,0,0,13,
        1,0,0,0,0,15,1,0,0,0,1,17,1,0,0,0,3,19,1,0,0,0,5,21,1,0,0,0,7,23,
        1,0,0,0,9,25,1,0,0,0,11,28,1,0,0,0,13,30,1,0,0,0,15,33,1,0,0,0,17,
        18,5,123,0,0,18,2,1,0,0,0,19,20,5,125,0,0,20,4,1,0,0,0,21,22,5,44,
        0,0,22,6,1,0,0,0,23,24,5,33,0,0,24,8,1,0,0,0,25,26,5,46,0,0,26,27,
        5,46,0,0,27,10,1,0,0,0,28,29,5,46,0,0,29,12,1,0,0,0,30,31,5,92,0,
        0,31,32,9,0,0,0,32,14,1,0,0,0,33,34,8,0,0,0,34,16,1,0,0,0,1,0,0
    ]

class HimarkLexer(Lexer):

    atn = ATNDeserializer().deserialize(serializedATN())

    decisionsToDFA = [ DFA(ds, i) for i, ds in enumerate(atn.decisionToState) ]

    LBRACE = 1
    RBRACE = 2
    COMMA = 3
    BANG = 4
    RANGE = 5
    DOT = 6
    ESC = 7
    CHAR = 8

    channelNames = [ u"DEFAULT_TOKEN_CHANNEL", u"HIDDEN" ]

    modeNames = [ "DEFAULT_MODE" ]

    literalNames = [ "<INVALID>",
            "'{'", "'}'", "','", "'!'", "'..'", "'.'" ]

    symbolicNames = [ "<INVALID>",
            "LBRACE", "RBRACE", "COMMA", "BANG", "RANGE", "DOT", "ESC", 
            "CHAR" ]

    ruleNames = [ "LBRACE", "RBRACE", "COMMA", "BANG", "RANGE", "DOT", "ESC", 
                  "CHAR" ]

    grammarFileName = "Himark.g4"

    def __init__(self, input=None, output:TextIO = sys.stdout):
        super().__init__(input, output)
        self.checkVersion("4.13.2")
        self._interp = LexerATNSimulator(self, self.atn, self.decisionsToDFA, PredictionContextCache())
        self._actions = None
        self._predicates = None


