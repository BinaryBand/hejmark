# Generated from HimarkParser.g4 by ANTLR 4.13.2
# encoding: utf-8
from antlr4 import *
from io import StringIO
import sys
if sys.version_info[1] > 5:
	from typing import TextIO
else:
	from typing.io import TextIO

def serializedATN():
    return [
        4,1,35,211,2,0,7,0,2,1,7,1,2,2,7,2,2,3,7,3,2,4,7,4,2,5,7,5,2,6,7,
        6,2,7,7,7,2,8,7,8,2,9,7,9,2,10,7,10,2,11,7,11,2,12,7,12,2,13,7,13,
        2,14,7,14,2,15,7,15,2,16,7,16,2,17,7,17,2,18,7,18,1,0,5,0,40,8,0,
        10,0,12,0,43,9,0,1,0,1,0,4,0,47,8,0,11,0,12,0,48,1,0,5,0,52,8,0,
        10,0,12,0,55,9,0,1,0,5,0,58,8,0,10,0,12,0,61,9,0,3,0,63,8,0,1,0,
        1,0,1,1,1,1,3,1,69,8,1,1,2,1,2,1,2,1,2,1,2,1,2,5,2,77,8,2,10,2,12,
        2,80,9,2,1,2,1,2,3,2,84,8,2,1,3,1,3,1,3,3,3,89,8,3,1,4,1,4,5,4,93,
        8,4,10,4,12,4,96,9,4,1,4,1,4,5,4,100,8,4,10,4,12,4,103,9,4,1,5,1,
        5,3,5,107,8,5,1,6,4,6,110,8,6,11,6,12,6,111,1,7,1,7,1,7,3,7,117,
        8,7,1,7,3,7,120,8,7,1,8,1,8,1,8,3,8,125,8,8,1,9,1,9,1,9,1,9,3,9,
        131,8,9,1,10,1,10,4,10,135,8,10,11,10,12,10,136,1,10,1,10,1,11,1,
        11,1,11,3,11,144,8,11,1,12,1,12,1,12,1,12,5,12,150,8,12,10,12,12,
        12,153,9,12,3,12,155,8,12,1,12,1,12,1,13,1,13,1,13,1,13,1,13,1,13,
        1,13,1,13,1,13,1,13,4,13,169,8,13,11,13,12,13,170,3,13,173,8,13,
        1,14,1,14,1,14,3,14,178,8,14,1,14,3,14,181,8,14,1,14,1,14,3,14,185,
        8,14,1,15,4,15,188,8,15,11,15,12,15,189,1,16,1,16,5,16,194,8,16,
        10,16,12,16,197,9,16,1,16,1,16,1,17,1,17,1,17,1,17,3,17,205,8,17,
        1,18,1,18,1,18,1,18,1,18,0,0,19,0,2,4,6,8,10,12,14,16,18,20,22,24,
        26,28,30,32,34,36,0,1,2,0,21,22,24,24,228,0,41,1,0,0,0,2,68,1,0,
        0,0,4,83,1,0,0,0,6,85,1,0,0,0,8,90,1,0,0,0,10,106,1,0,0,0,12,109,
        1,0,0,0,14,113,1,0,0,0,16,124,1,0,0,0,18,130,1,0,0,0,20,132,1,0,
        0,0,22,140,1,0,0,0,24,145,1,0,0,0,26,172,1,0,0,0,28,184,1,0,0,0,
        30,187,1,0,0,0,32,191,1,0,0,0,34,204,1,0,0,0,36,206,1,0,0,0,38,40,
        5,15,0,0,39,38,1,0,0,0,40,43,1,0,0,0,41,39,1,0,0,0,41,42,1,0,0,0,
        42,62,1,0,0,0,43,41,1,0,0,0,44,53,3,2,1,0,45,47,5,15,0,0,46,45,1,
        0,0,0,47,48,1,0,0,0,48,46,1,0,0,0,48,49,1,0,0,0,49,50,1,0,0,0,50,
        52,3,2,1,0,51,46,1,0,0,0,52,55,1,0,0,0,53,51,1,0,0,0,53,54,1,0,0,
        0,54,59,1,0,0,0,55,53,1,0,0,0,56,58,5,15,0,0,57,56,1,0,0,0,58,61,
        1,0,0,0,59,57,1,0,0,0,59,60,1,0,0,0,60,63,1,0,0,0,61,59,1,0,0,0,
        62,44,1,0,0,0,62,63,1,0,0,0,63,64,1,0,0,0,64,65,5,0,0,1,65,1,1,0,
        0,0,66,69,3,4,2,0,67,69,3,8,4,0,68,66,1,0,0,0,68,67,1,0,0,0,69,3,
        1,0,0,0,70,71,5,1,0,0,71,72,5,9,0,0,72,73,5,4,0,0,73,84,3,12,6,0,
        74,78,5,9,0,0,75,77,3,6,3,0,76,75,1,0,0,0,77,80,1,0,0,0,78,76,1,
        0,0,0,78,79,1,0,0,0,79,81,1,0,0,0,80,78,1,0,0,0,81,82,5,2,0,0,82,
        84,3,12,6,0,83,70,1,0,0,0,83,74,1,0,0,0,84,5,1,0,0,0,85,88,5,9,0,
        0,86,87,5,5,0,0,87,89,5,9,0,0,88,86,1,0,0,0,88,89,1,0,0,0,89,7,1,
        0,0,0,90,101,3,10,5,0,91,93,5,15,0,0,92,91,1,0,0,0,93,96,1,0,0,0,
        94,92,1,0,0,0,94,95,1,0,0,0,95,97,1,0,0,0,96,94,1,0,0,0,97,98,5,
        3,0,0,98,100,3,10,5,0,99,94,1,0,0,0,100,103,1,0,0,0,101,99,1,0,0,
        0,101,102,1,0,0,0,102,9,1,0,0,0,103,101,1,0,0,0,104,107,3,12,6,0,
        105,107,3,32,16,0,106,104,1,0,0,0,106,105,1,0,0,0,107,11,1,0,0,0,
        108,110,3,14,7,0,109,108,1,0,0,0,110,111,1,0,0,0,111,109,1,0,0,0,
        111,112,1,0,0,0,112,13,1,0,0,0,113,116,3,16,8,0,114,115,5,7,0,0,
        115,117,3,18,9,0,116,114,1,0,0,0,116,117,1,0,0,0,117,119,1,0,0,0,
        118,120,3,20,10,0,119,118,1,0,0,0,119,120,1,0,0,0,120,15,1,0,0,0,
        121,125,3,24,12,0,122,125,5,8,0,0,123,125,5,6,0,0,124,121,1,0,0,
        0,124,122,1,0,0,0,124,123,1,0,0,0,125,17,1,0,0,0,126,131,5,10,0,
        0,127,131,5,9,0,0,128,131,3,30,15,0,129,131,3,24,12,0,130,126,1,
        0,0,0,130,127,1,0,0,0,130,128,1,0,0,0,130,129,1,0,0,0,131,19,1,0,
        0,0,132,134,5,12,0,0,133,135,3,22,11,0,134,133,1,0,0,0,135,136,1,
        0,0,0,136,134,1,0,0,0,136,137,1,0,0,0,137,138,1,0,0,0,138,139,5,
        25,0,0,139,21,1,0,0,0,140,143,5,27,0,0,141,142,5,5,0,0,142,144,5,
        27,0,0,143,141,1,0,0,0,143,144,1,0,0,0,144,23,1,0,0,0,145,154,5,
        11,0,0,146,151,3,26,13,0,147,148,5,18,0,0,148,150,3,26,13,0,149,
        147,1,0,0,0,150,153,1,0,0,0,151,149,1,0,0,0,151,152,1,0,0,0,152,
        155,1,0,0,0,153,151,1,0,0,0,154,146,1,0,0,0,154,155,1,0,0,0,155,
        156,1,0,0,0,156,157,5,17,0,0,157,25,1,0,0,0,158,159,3,30,15,0,159,
        160,5,5,0,0,160,161,3,30,15,0,161,173,1,0,0,0,162,163,3,30,15,0,
        163,164,5,5,0,0,164,173,1,0,0,0,165,166,5,19,0,0,166,173,3,24,12,
        0,167,169,3,28,14,0,168,167,1,0,0,0,169,170,1,0,0,0,170,168,1,0,
        0,0,170,171,1,0,0,0,171,173,1,0,0,0,172,158,1,0,0,0,172,162,1,0,
        0,0,172,165,1,0,0,0,172,168,1,0,0,0,173,27,1,0,0,0,174,177,3,16,
        8,0,175,176,5,7,0,0,176,178,3,18,9,0,177,175,1,0,0,0,177,178,1,0,
        0,0,178,180,1,0,0,0,179,181,3,20,10,0,180,179,1,0,0,0,180,181,1,
        0,0,0,181,185,1,0,0,0,182,185,5,20,0,0,183,185,3,30,15,0,184,174,
        1,0,0,0,184,182,1,0,0,0,184,183,1,0,0,0,185,29,1,0,0,0,186,188,7,
        0,0,0,187,186,1,0,0,0,188,189,1,0,0,0,189,187,1,0,0,0,189,190,1,
        0,0,0,190,31,1,0,0,0,191,195,5,13,0,0,192,194,3,34,17,0,193,192,
        1,0,0,0,194,197,1,0,0,0,195,193,1,0,0,0,195,196,1,0,0,0,196,198,
        1,0,0,0,197,195,1,0,0,0,198,199,5,28,0,0,199,33,1,0,0,0,200,205,
        5,32,0,0,201,205,5,30,0,0,202,205,5,31,0,0,203,205,3,36,18,0,204,
        200,1,0,0,0,204,201,1,0,0,0,204,202,1,0,0,0,204,203,1,0,0,0,205,
        35,1,0,0,0,206,207,5,29,0,0,207,208,5,34,0,0,208,209,5,33,0,0,209,
        37,1,0,0,0,29,41,48,53,59,62,68,78,83,88,94,101,106,111,116,119,
        124,130,136,143,151,154,170,172,177,180,184,189,195,204
    ]

class HimarkParser ( Parser ):

    grammarFileName = "HimarkParser.g4"

    atn = ATNDeserializer().deserialize(serializedATN())

    decisionsToDFA = [ DFA(ds, i) for i, ds in enumerate(atn.decisionToState) ]

    sharedContextCache = PredictionContextCache()

    literalNames = [ "<INVALID>", "'uni'", "':='", "'=>'", "'='", "<INVALID>", 
                     "<INVALID>", "<INVALID>", "<INVALID>", "<INVALID>", 
                     "<INVALID>", "<INVALID>", "'['", "<INVALID>", "<INVALID>", 
                     "<INVALID>", "<INVALID>", "'}'", "','", "'!'", "'&'", 
                     "'.'", "<INVALID>", "<INVALID>", "<INVALID>", "']'", 
                     "<INVALID>", "<INVALID>", "<INVALID>", "'{{'", "<INVALID>", 
                     "<INVALID>", "<INVALID>", "'}}'" ]

    symbolicNames = [ "<INVALID>", "UNI", "WALRUS", "ARROW", "EQ", "RANGE", 
                      "USCORE", "CARET", "REF", "IDENT", "NUM", "LBRACE", 
                      "LBRACK", "TMPL_OPEN", "COMMENT", "NL", "WS", "RBRACE", 
                      "COMMA", "BANG", "AMP", "DOT", "ESC", "B_WS", "CHAR", 
                      "RBRACK", "A_WS", "ARG", "TMPL_CLOSE", "MOUST_OPEN", 
                      "TMPL_ESC", "TMPL_LBRACE", "TMPL_TEXT", "MOUST_CLOSE", 
                      "CAPTURE", "I_WS" ]

    RULE_script = 0
    RULE_line = 1
    RULE_declaration = 2
    RULE_param = 3
    RULE_statement = 4
    RULE_step = 5
    RULE_expr = 6
    RULE_unit = 7
    RULE_base = 8
    RULE_exponent = 9
    RULE_pipeline = 10
    RULE_pipeItem = 11
    RULE_universe = 12
    RULE_member = 13
    RULE_segment = 14
    RULE_face = 15
    RULE_template = 16
    RULE_part = 17
    RULE_interp = 18

    ruleNames =  [ "script", "line", "declaration", "param", "statement", 
                   "step", "expr", "unit", "base", "exponent", "pipeline", 
                   "pipeItem", "universe", "member", "segment", "face", 
                   "template", "part", "interp" ]

    EOF = Token.EOF
    UNI=1
    WALRUS=2
    ARROW=3
    EQ=4
    RANGE=5
    USCORE=6
    CARET=7
    REF=8
    IDENT=9
    NUM=10
    LBRACE=11
    LBRACK=12
    TMPL_OPEN=13
    COMMENT=14
    NL=15
    WS=16
    RBRACE=17
    COMMA=18
    BANG=19
    AMP=20
    DOT=21
    ESC=22
    B_WS=23
    CHAR=24
    RBRACK=25
    A_WS=26
    ARG=27
    TMPL_CLOSE=28
    MOUST_OPEN=29
    TMPL_ESC=30
    TMPL_LBRACE=31
    TMPL_TEXT=32
    MOUST_CLOSE=33
    CAPTURE=34
    I_WS=35

    def __init__(self, input:TokenStream, output:TextIO = sys.stdout):
        super().__init__(input, output)
        self.checkVersion("4.13.2")
        self._interp = ParserATNSimulator(self, self.atn, self.decisionsToDFA, self.sharedContextCache)
        self._predicates = None




    class ScriptContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def EOF(self):
            return self.getToken(HimarkParser.EOF, 0)

        def NL(self, i:int=None):
            if i is None:
                return self.getTokens(HimarkParser.NL)
            else:
                return self.getToken(HimarkParser.NL, i)

        def line(self, i:int=None):
            if i is None:
                return self.getTypedRuleContexts(HimarkParser.LineContext)
            else:
                return self.getTypedRuleContext(HimarkParser.LineContext,i)


        def getRuleIndex(self):
            return HimarkParser.RULE_script

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterScript" ):
                listener.enterScript(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitScript" ):
                listener.exitScript(self)




    def script(self):

        localctx = HimarkParser.ScriptContext(self, self._ctx, self.state)
        self.enterRule(localctx, 0, self.RULE_script)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 41
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            while _la==15:
                self.state = 38
                self.match(HimarkParser.NL)
                self.state = 43
                self._errHandler.sync(self)
                _la = self._input.LA(1)

            self.state = 62
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            if (((_la) & ~0x3f) == 0 and ((1 << _la) & 11074) != 0):
                self.state = 44
                self.line()
                self.state = 53
                self._errHandler.sync(self)
                _alt = self._interp.adaptivePredict(self._input,2,self._ctx)
                while _alt!=2 and _alt!=ATN.INVALID_ALT_NUMBER:
                    if _alt==1:
                        self.state = 46 
                        self._errHandler.sync(self)
                        _la = self._input.LA(1)
                        while True:
                            self.state = 45
                            self.match(HimarkParser.NL)
                            self.state = 48 
                            self._errHandler.sync(self)
                            _la = self._input.LA(1)
                            if not (_la==15):
                                break

                        self.state = 50
                        self.line() 
                    self.state = 55
                    self._errHandler.sync(self)
                    _alt = self._interp.adaptivePredict(self._input,2,self._ctx)

                self.state = 59
                self._errHandler.sync(self)
                _la = self._input.LA(1)
                while _la==15:
                    self.state = 56
                    self.match(HimarkParser.NL)
                    self.state = 61
                    self._errHandler.sync(self)
                    _la = self._input.LA(1)



            self.state = 64
            self.match(HimarkParser.EOF)
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class LineContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def declaration(self):
            return self.getTypedRuleContext(HimarkParser.DeclarationContext,0)


        def statement(self):
            return self.getTypedRuleContext(HimarkParser.StatementContext,0)


        def getRuleIndex(self):
            return HimarkParser.RULE_line

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterLine" ):
                listener.enterLine(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitLine" ):
                listener.exitLine(self)




    def line(self):

        localctx = HimarkParser.LineContext(self, self._ctx, self.state)
        self.enterRule(localctx, 2, self.RULE_line)
        try:
            self.state = 68
            self._errHandler.sync(self)
            token = self._input.LA(1)
            if token in [1, 9]:
                self.enterOuterAlt(localctx, 1)
                self.state = 66
                self.declaration()
                pass
            elif token in [6, 8, 11, 13]:
                self.enterOuterAlt(localctx, 2)
                self.state = 67
                self.statement()
                pass
            else:
                raise NoViableAltException(self)

        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class DeclarationContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser


        def getRuleIndex(self):
            return HimarkParser.RULE_declaration

     
        def copyFrom(self, ctx:ParserRuleContext):
            super().copyFrom(ctx)



    class DefDeclContext(DeclarationContext):

        def __init__(self, parser, ctx:ParserRuleContext): # actually a HimarkParser.DeclarationContext
            super().__init__(parser)
            self.copyFrom(ctx)

        def IDENT(self):
            return self.getToken(HimarkParser.IDENT, 0)
        def WALRUS(self):
            return self.getToken(HimarkParser.WALRUS, 0)
        def expr(self):
            return self.getTypedRuleContext(HimarkParser.ExprContext,0)

        def param(self, i:int=None):
            if i is None:
                return self.getTypedRuleContexts(HimarkParser.ParamContext)
            else:
                return self.getTypedRuleContext(HimarkParser.ParamContext,i)


        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterDefDecl" ):
                listener.enterDefDecl(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitDefDecl" ):
                listener.exitDefDecl(self)


    class UniDeclContext(DeclarationContext):

        def __init__(self, parser, ctx:ParserRuleContext): # actually a HimarkParser.DeclarationContext
            super().__init__(parser)
            self.copyFrom(ctx)

        def UNI(self):
            return self.getToken(HimarkParser.UNI, 0)
        def IDENT(self):
            return self.getToken(HimarkParser.IDENT, 0)
        def EQ(self):
            return self.getToken(HimarkParser.EQ, 0)
        def expr(self):
            return self.getTypedRuleContext(HimarkParser.ExprContext,0)


        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterUniDecl" ):
                listener.enterUniDecl(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitUniDecl" ):
                listener.exitUniDecl(self)



    def declaration(self):

        localctx = HimarkParser.DeclarationContext(self, self._ctx, self.state)
        self.enterRule(localctx, 4, self.RULE_declaration)
        self._la = 0 # Token type
        try:
            self.state = 83
            self._errHandler.sync(self)
            token = self._input.LA(1)
            if token in [1]:
                localctx = HimarkParser.UniDeclContext(self, localctx)
                self.enterOuterAlt(localctx, 1)
                self.state = 70
                self.match(HimarkParser.UNI)
                self.state = 71
                self.match(HimarkParser.IDENT)
                self.state = 72
                self.match(HimarkParser.EQ)
                self.state = 73
                self.expr()
                pass
            elif token in [9]:
                localctx = HimarkParser.DefDeclContext(self, localctx)
                self.enterOuterAlt(localctx, 2)
                self.state = 74
                self.match(HimarkParser.IDENT)
                self.state = 78
                self._errHandler.sync(self)
                _la = self._input.LA(1)
                while _la==9:
                    self.state = 75
                    self.param()
                    self.state = 80
                    self._errHandler.sync(self)
                    _la = self._input.LA(1)

                self.state = 81
                self.match(HimarkParser.WALRUS)
                self.state = 82
                self.expr()
                pass
            else:
                raise NoViableAltException(self)

        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class ParamContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def IDENT(self, i:int=None):
            if i is None:
                return self.getTokens(HimarkParser.IDENT)
            else:
                return self.getToken(HimarkParser.IDENT, i)

        def RANGE(self):
            return self.getToken(HimarkParser.RANGE, 0)

        def getRuleIndex(self):
            return HimarkParser.RULE_param

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterParam" ):
                listener.enterParam(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitParam" ):
                listener.exitParam(self)




    def param(self):

        localctx = HimarkParser.ParamContext(self, self._ctx, self.state)
        self.enterRule(localctx, 6, self.RULE_param)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 85
            self.match(HimarkParser.IDENT)
            self.state = 88
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            if _la==5:
                self.state = 86
                self.match(HimarkParser.RANGE)
                self.state = 87
                self.match(HimarkParser.IDENT)


        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class StatementContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def step(self, i:int=None):
            if i is None:
                return self.getTypedRuleContexts(HimarkParser.StepContext)
            else:
                return self.getTypedRuleContext(HimarkParser.StepContext,i)


        def ARROW(self, i:int=None):
            if i is None:
                return self.getTokens(HimarkParser.ARROW)
            else:
                return self.getToken(HimarkParser.ARROW, i)

        def NL(self, i:int=None):
            if i is None:
                return self.getTokens(HimarkParser.NL)
            else:
                return self.getToken(HimarkParser.NL, i)

        def getRuleIndex(self):
            return HimarkParser.RULE_statement

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterStatement" ):
                listener.enterStatement(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitStatement" ):
                listener.exitStatement(self)




    def statement(self):

        localctx = HimarkParser.StatementContext(self, self._ctx, self.state)
        self.enterRule(localctx, 8, self.RULE_statement)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 90
            self.step()
            self.state = 101
            self._errHandler.sync(self)
            _alt = self._interp.adaptivePredict(self._input,10,self._ctx)
            while _alt!=2 and _alt!=ATN.INVALID_ALT_NUMBER:
                if _alt==1:
                    self.state = 94
                    self._errHandler.sync(self)
                    _la = self._input.LA(1)
                    while _la==15:
                        self.state = 91
                        self.match(HimarkParser.NL)
                        self.state = 96
                        self._errHandler.sync(self)
                        _la = self._input.LA(1)

                    self.state = 97
                    self.match(HimarkParser.ARROW)
                    self.state = 98
                    self.step() 
                self.state = 103
                self._errHandler.sync(self)
                _alt = self._interp.adaptivePredict(self._input,10,self._ctx)

        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class StepContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser


        def getRuleIndex(self):
            return HimarkParser.RULE_step

     
        def copyFrom(self, ctx:ParserRuleContext):
            super().copyFrom(ctx)



    class TemplateStepContext(StepContext):

        def __init__(self, parser, ctx:ParserRuleContext): # actually a HimarkParser.StepContext
            super().__init__(parser)
            self.copyFrom(ctx)

        def template(self):
            return self.getTypedRuleContext(HimarkParser.TemplateContext,0)


        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterTemplateStep" ):
                listener.enterTemplateStep(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitTemplateStep" ):
                listener.exitTemplateStep(self)


    class QueryStepContext(StepContext):

        def __init__(self, parser, ctx:ParserRuleContext): # actually a HimarkParser.StepContext
            super().__init__(parser)
            self.copyFrom(ctx)

        def expr(self):
            return self.getTypedRuleContext(HimarkParser.ExprContext,0)


        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterQueryStep" ):
                listener.enterQueryStep(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitQueryStep" ):
                listener.exitQueryStep(self)



    def step(self):

        localctx = HimarkParser.StepContext(self, self._ctx, self.state)
        self.enterRule(localctx, 10, self.RULE_step)
        try:
            self.state = 106
            self._errHandler.sync(self)
            token = self._input.LA(1)
            if token in [6, 8, 11]:
                localctx = HimarkParser.QueryStepContext(self, localctx)
                self.enterOuterAlt(localctx, 1)
                self.state = 104
                self.expr()
                pass
            elif token in [13]:
                localctx = HimarkParser.TemplateStepContext(self, localctx)
                self.enterOuterAlt(localctx, 2)
                self.state = 105
                self.template()
                pass
            else:
                raise NoViableAltException(self)

        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class ExprContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def unit(self, i:int=None):
            if i is None:
                return self.getTypedRuleContexts(HimarkParser.UnitContext)
            else:
                return self.getTypedRuleContext(HimarkParser.UnitContext,i)


        def getRuleIndex(self):
            return HimarkParser.RULE_expr

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterExpr" ):
                listener.enterExpr(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitExpr" ):
                listener.exitExpr(self)




    def expr(self):

        localctx = HimarkParser.ExprContext(self, self._ctx, self.state)
        self.enterRule(localctx, 12, self.RULE_expr)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 109 
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            while True:
                self.state = 108
                self.unit()
                self.state = 111 
                self._errHandler.sync(self)
                _la = self._input.LA(1)
                if not ((((_la) & ~0x3f) == 0 and ((1 << _la) & 2368) != 0)):
                    break

        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class UnitContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def base(self):
            return self.getTypedRuleContext(HimarkParser.BaseContext,0)


        def CARET(self):
            return self.getToken(HimarkParser.CARET, 0)

        def exponent(self):
            return self.getTypedRuleContext(HimarkParser.ExponentContext,0)


        def pipeline(self):
            return self.getTypedRuleContext(HimarkParser.PipelineContext,0)


        def getRuleIndex(self):
            return HimarkParser.RULE_unit

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterUnit" ):
                listener.enterUnit(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitUnit" ):
                listener.exitUnit(self)




    def unit(self):

        localctx = HimarkParser.UnitContext(self, self._ctx, self.state)
        self.enterRule(localctx, 14, self.RULE_unit)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 113
            self.base()
            self.state = 116
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            if _la==7:
                self.state = 114
                self.match(HimarkParser.CARET)
                self.state = 115
                self.exponent()


            self.state = 119
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            if _la==12:
                self.state = 118
                self.pipeline()


        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class BaseContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser


        def getRuleIndex(self):
            return HimarkParser.RULE_base

     
        def copyFrom(self, ctx:ParserRuleContext):
            super().copyFrom(ctx)



    class UniverseBaseContext(BaseContext):

        def __init__(self, parser, ctx:ParserRuleContext): # actually a HimarkParser.BaseContext
            super().__init__(parser)
            self.copyFrom(ctx)

        def universe(self):
            return self.getTypedRuleContext(HimarkParser.UniverseContext,0)


        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterUniverseBase" ):
                listener.enterUniverseBase(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitUniverseBase" ):
                listener.exitUniverseBase(self)


    class OperandBaseContext(BaseContext):

        def __init__(self, parser, ctx:ParserRuleContext): # actually a HimarkParser.BaseContext
            super().__init__(parser)
            self.copyFrom(ctx)

        def USCORE(self):
            return self.getToken(HimarkParser.USCORE, 0)

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterOperandBase" ):
                listener.enterOperandBase(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitOperandBase" ):
                listener.exitOperandBase(self)


    class ReferenceBaseContext(BaseContext):

        def __init__(self, parser, ctx:ParserRuleContext): # actually a HimarkParser.BaseContext
            super().__init__(parser)
            self.copyFrom(ctx)

        def REF(self):
            return self.getToken(HimarkParser.REF, 0)

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterReferenceBase" ):
                listener.enterReferenceBase(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitReferenceBase" ):
                listener.exitReferenceBase(self)



    def base(self):

        localctx = HimarkParser.BaseContext(self, self._ctx, self.state)
        self.enterRule(localctx, 16, self.RULE_base)
        try:
            self.state = 124
            self._errHandler.sync(self)
            token = self._input.LA(1)
            if token in [11]:
                localctx = HimarkParser.UniverseBaseContext(self, localctx)
                self.enterOuterAlt(localctx, 1)
                self.state = 121
                self.universe()
                pass
            elif token in [8]:
                localctx = HimarkParser.ReferenceBaseContext(self, localctx)
                self.enterOuterAlt(localctx, 2)
                self.state = 122
                self.match(HimarkParser.REF)
                pass
            elif token in [6]:
                localctx = HimarkParser.OperandBaseContext(self, localctx)
                self.enterOuterAlt(localctx, 3)
                self.state = 123
                self.match(HimarkParser.USCORE)
                pass
            else:
                raise NoViableAltException(self)

        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class ExponentContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def NUM(self):
            return self.getToken(HimarkParser.NUM, 0)

        def IDENT(self):
            return self.getToken(HimarkParser.IDENT, 0)

        def face(self):
            return self.getTypedRuleContext(HimarkParser.FaceContext,0)


        def universe(self):
            return self.getTypedRuleContext(HimarkParser.UniverseContext,0)


        def getRuleIndex(self):
            return HimarkParser.RULE_exponent

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterExponent" ):
                listener.enterExponent(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitExponent" ):
                listener.exitExponent(self)




    def exponent(self):

        localctx = HimarkParser.ExponentContext(self, self._ctx, self.state)
        self.enterRule(localctx, 18, self.RULE_exponent)
        try:
            self.state = 130
            self._errHandler.sync(self)
            token = self._input.LA(1)
            if token in [10]:
                self.enterOuterAlt(localctx, 1)
                self.state = 126
                self.match(HimarkParser.NUM)
                pass
            elif token in [9]:
                self.enterOuterAlt(localctx, 2)
                self.state = 127
                self.match(HimarkParser.IDENT)
                pass
            elif token in [21, 22, 24]:
                self.enterOuterAlt(localctx, 3)
                self.state = 128
                self.face()
                pass
            elif token in [11]:
                self.enterOuterAlt(localctx, 4)
                self.state = 129
                self.universe()
                pass
            else:
                raise NoViableAltException(self)

        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class PipelineContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def LBRACK(self):
            return self.getToken(HimarkParser.LBRACK, 0)

        def RBRACK(self):
            return self.getToken(HimarkParser.RBRACK, 0)

        def pipeItem(self, i:int=None):
            if i is None:
                return self.getTypedRuleContexts(HimarkParser.PipeItemContext)
            else:
                return self.getTypedRuleContext(HimarkParser.PipeItemContext,i)


        def getRuleIndex(self):
            return HimarkParser.RULE_pipeline

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterPipeline" ):
                listener.enterPipeline(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitPipeline" ):
                listener.exitPipeline(self)




    def pipeline(self):

        localctx = HimarkParser.PipelineContext(self, self._ctx, self.state)
        self.enterRule(localctx, 20, self.RULE_pipeline)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 132
            self.match(HimarkParser.LBRACK)
            self.state = 134 
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            while True:
                self.state = 133
                self.pipeItem()
                self.state = 136 
                self._errHandler.sync(self)
                _la = self._input.LA(1)
                if not (_la==27):
                    break

            self.state = 138
            self.match(HimarkParser.RBRACK)
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class PipeItemContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def ARG(self, i:int=None):
            if i is None:
                return self.getTokens(HimarkParser.ARG)
            else:
                return self.getToken(HimarkParser.ARG, i)

        def RANGE(self):
            return self.getToken(HimarkParser.RANGE, 0)

        def getRuleIndex(self):
            return HimarkParser.RULE_pipeItem

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterPipeItem" ):
                listener.enterPipeItem(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitPipeItem" ):
                listener.exitPipeItem(self)




    def pipeItem(self):

        localctx = HimarkParser.PipeItemContext(self, self._ctx, self.state)
        self.enterRule(localctx, 22, self.RULE_pipeItem)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 140
            self.match(HimarkParser.ARG)
            self.state = 143
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            if _la==5:
                self.state = 141
                self.match(HimarkParser.RANGE)
                self.state = 142
                self.match(HimarkParser.ARG)


        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class UniverseContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def LBRACE(self):
            return self.getToken(HimarkParser.LBRACE, 0)

        def RBRACE(self):
            return self.getToken(HimarkParser.RBRACE, 0)

        def member(self, i:int=None):
            if i is None:
                return self.getTypedRuleContexts(HimarkParser.MemberContext)
            else:
                return self.getTypedRuleContext(HimarkParser.MemberContext,i)


        def COMMA(self, i:int=None):
            if i is None:
                return self.getTokens(HimarkParser.COMMA)
            else:
                return self.getToken(HimarkParser.COMMA, i)

        def getRuleIndex(self):
            return HimarkParser.RULE_universe

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterUniverse" ):
                listener.enterUniverse(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitUniverse" ):
                listener.exitUniverse(self)




    def universe(self):

        localctx = HimarkParser.UniverseContext(self, self._ctx, self.state)
        self.enterRule(localctx, 24, self.RULE_universe)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 145
            self.match(HimarkParser.LBRACE)
            self.state = 154
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            if (((_la) & ~0x3f) == 0 and ((1 << _la) & 24643904) != 0):
                self.state = 146
                self.member()
                self.state = 151
                self._errHandler.sync(self)
                _la = self._input.LA(1)
                while _la==18:
                    self.state = 147
                    self.match(HimarkParser.COMMA)
                    self.state = 148
                    self.member()
                    self.state = 153
                    self._errHandler.sync(self)
                    _la = self._input.LA(1)



            self.state = 156
            self.match(HimarkParser.RBRACE)
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class MemberContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser


        def getRuleIndex(self):
            return HimarkParser.RULE_member

     
        def copyFrom(self, ctx:ParserRuleContext):
            super().copyFrom(ctx)



    class SubtractMemberContext(MemberContext):

        def __init__(self, parser, ctx:ParserRuleContext): # actually a HimarkParser.MemberContext
            super().__init__(parser)
            self.copyFrom(ctx)

        def BANG(self):
            return self.getToken(HimarkParser.BANG, 0)
        def universe(self):
            return self.getTypedRuleContext(HimarkParser.UniverseContext,0)


        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterSubtractMember" ):
                listener.enterSubtractMember(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitSubtractMember" ):
                listener.exitSubtractMember(self)


    class RangeMemberContext(MemberContext):

        def __init__(self, parser, ctx:ParserRuleContext): # actually a HimarkParser.MemberContext
            super().__init__(parser)
            self.copyFrom(ctx)

        def face(self, i:int=None):
            if i is None:
                return self.getTypedRuleContexts(HimarkParser.FaceContext)
            else:
                return self.getTypedRuleContext(HimarkParser.FaceContext,i)

        def RANGE(self):
            return self.getToken(HimarkParser.RANGE, 0)

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterRangeMember" ):
                listener.enterRangeMember(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitRangeMember" ):
                listener.exitRangeMember(self)


    class FinalMemberContext(MemberContext):

        def __init__(self, parser, ctx:ParserRuleContext): # actually a HimarkParser.MemberContext
            super().__init__(parser)
            self.copyFrom(ctx)

        def face(self):
            return self.getTypedRuleContext(HimarkParser.FaceContext,0)

        def RANGE(self):
            return self.getToken(HimarkParser.RANGE, 0)

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterFinalMember" ):
                listener.enterFinalMember(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitFinalMember" ):
                listener.exitFinalMember(self)


    class SegmentsMemberContext(MemberContext):

        def __init__(self, parser, ctx:ParserRuleContext): # actually a HimarkParser.MemberContext
            super().__init__(parser)
            self.copyFrom(ctx)

        def segment(self, i:int=None):
            if i is None:
                return self.getTypedRuleContexts(HimarkParser.SegmentContext)
            else:
                return self.getTypedRuleContext(HimarkParser.SegmentContext,i)


        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterSegmentsMember" ):
                listener.enterSegmentsMember(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitSegmentsMember" ):
                listener.exitSegmentsMember(self)



    def member(self):

        localctx = HimarkParser.MemberContext(self, self._ctx, self.state)
        self.enterRule(localctx, 26, self.RULE_member)
        self._la = 0 # Token type
        try:
            self.state = 172
            self._errHandler.sync(self)
            la_ = self._interp.adaptivePredict(self._input,22,self._ctx)
            if la_ == 1:
                localctx = HimarkParser.RangeMemberContext(self, localctx)
                self.enterOuterAlt(localctx, 1)
                self.state = 158
                self.face()
                self.state = 159
                self.match(HimarkParser.RANGE)
                self.state = 160
                self.face()
                pass

            elif la_ == 2:
                localctx = HimarkParser.FinalMemberContext(self, localctx)
                self.enterOuterAlt(localctx, 2)
                self.state = 162
                self.face()
                self.state = 163
                self.match(HimarkParser.RANGE)
                pass

            elif la_ == 3:
                localctx = HimarkParser.SubtractMemberContext(self, localctx)
                self.enterOuterAlt(localctx, 3)
                self.state = 165
                self.match(HimarkParser.BANG)
                self.state = 166
                self.universe()
                pass

            elif la_ == 4:
                localctx = HimarkParser.SegmentsMemberContext(self, localctx)
                self.enterOuterAlt(localctx, 4)
                self.state = 168 
                self._errHandler.sync(self)
                _la = self._input.LA(1)
                while True:
                    self.state = 167
                    self.segment()
                    self.state = 170 
                    self._errHandler.sync(self)
                    _la = self._input.LA(1)
                    if not ((((_la) & ~0x3f) == 0 and ((1 << _la) & 24119616) != 0)):
                        break

                pass


        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class SegmentContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def base(self):
            return self.getTypedRuleContext(HimarkParser.BaseContext,0)


        def CARET(self):
            return self.getToken(HimarkParser.CARET, 0)

        def exponent(self):
            return self.getTypedRuleContext(HimarkParser.ExponentContext,0)


        def pipeline(self):
            return self.getTypedRuleContext(HimarkParser.PipelineContext,0)


        def AMP(self):
            return self.getToken(HimarkParser.AMP, 0)

        def face(self):
            return self.getTypedRuleContext(HimarkParser.FaceContext,0)


        def getRuleIndex(self):
            return HimarkParser.RULE_segment

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterSegment" ):
                listener.enterSegment(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitSegment" ):
                listener.exitSegment(self)




    def segment(self):

        localctx = HimarkParser.SegmentContext(self, self._ctx, self.state)
        self.enterRule(localctx, 28, self.RULE_segment)
        self._la = 0 # Token type
        try:
            self.state = 184
            self._errHandler.sync(self)
            token = self._input.LA(1)
            if token in [6, 8, 11]:
                self.enterOuterAlt(localctx, 1)
                self.state = 174
                self.base()
                self.state = 177
                self._errHandler.sync(self)
                _la = self._input.LA(1)
                if _la==7:
                    self.state = 175
                    self.match(HimarkParser.CARET)
                    self.state = 176
                    self.exponent()


                self.state = 180
                self._errHandler.sync(self)
                _la = self._input.LA(1)
                if _la==12:
                    self.state = 179
                    self.pipeline()


                pass
            elif token in [20]:
                self.enterOuterAlt(localctx, 2)
                self.state = 182
                self.match(HimarkParser.AMP)
                pass
            elif token in [21, 22, 24]:
                self.enterOuterAlt(localctx, 3)
                self.state = 183
                self.face()
                pass
            else:
                raise NoViableAltException(self)

        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class FaceContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def CHAR(self, i:int=None):
            if i is None:
                return self.getTokens(HimarkParser.CHAR)
            else:
                return self.getToken(HimarkParser.CHAR, i)

        def DOT(self, i:int=None):
            if i is None:
                return self.getTokens(HimarkParser.DOT)
            else:
                return self.getToken(HimarkParser.DOT, i)

        def ESC(self, i:int=None):
            if i is None:
                return self.getTokens(HimarkParser.ESC)
            else:
                return self.getToken(HimarkParser.ESC, i)

        def getRuleIndex(self):
            return HimarkParser.RULE_face

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterFace" ):
                listener.enterFace(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitFace" ):
                listener.exitFace(self)




    def face(self):

        localctx = HimarkParser.FaceContext(self, self._ctx, self.state)
        self.enterRule(localctx, 30, self.RULE_face)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 187 
            self._errHandler.sync(self)
            _alt = 1
            while _alt!=2 and _alt!=ATN.INVALID_ALT_NUMBER:
                if _alt == 1:
                    self.state = 186
                    _la = self._input.LA(1)
                    if not((((_la) & ~0x3f) == 0 and ((1 << _la) & 23068672) != 0)):
                        self._errHandler.recoverInline(self)
                    else:
                        self._errHandler.reportMatch(self)
                        self.consume()

                else:
                    raise NoViableAltException(self)
                self.state = 189 
                self._errHandler.sync(self)
                _alt = self._interp.adaptivePredict(self._input,26,self._ctx)

        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class TemplateContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def TMPL_OPEN(self):
            return self.getToken(HimarkParser.TMPL_OPEN, 0)

        def TMPL_CLOSE(self):
            return self.getToken(HimarkParser.TMPL_CLOSE, 0)

        def part(self, i:int=None):
            if i is None:
                return self.getTypedRuleContexts(HimarkParser.PartContext)
            else:
                return self.getTypedRuleContext(HimarkParser.PartContext,i)


        def getRuleIndex(self):
            return HimarkParser.RULE_template

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterTemplate" ):
                listener.enterTemplate(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitTemplate" ):
                listener.exitTemplate(self)




    def template(self):

        localctx = HimarkParser.TemplateContext(self, self._ctx, self.state)
        self.enterRule(localctx, 32, self.RULE_template)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 191
            self.match(HimarkParser.TMPL_OPEN)
            self.state = 195
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            while (((_la) & ~0x3f) == 0 and ((1 << _la) & 8053063680) != 0):
                self.state = 192
                self.part()
                self.state = 197
                self._errHandler.sync(self)
                _la = self._input.LA(1)

            self.state = 198
            self.match(HimarkParser.TMPL_CLOSE)
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class PartContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser


        def getRuleIndex(self):
            return HimarkParser.RULE_part

     
        def copyFrom(self, ctx:ParserRuleContext):
            super().copyFrom(ctx)



    class TextPartContext(PartContext):

        def __init__(self, parser, ctx:ParserRuleContext): # actually a HimarkParser.PartContext
            super().__init__(parser)
            self.copyFrom(ctx)

        def TMPL_TEXT(self):
            return self.getToken(HimarkParser.TMPL_TEXT, 0)

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterTextPart" ):
                listener.enterTextPart(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitTextPart" ):
                listener.exitTextPart(self)


    class InterpPartContext(PartContext):

        def __init__(self, parser, ctx:ParserRuleContext): # actually a HimarkParser.PartContext
            super().__init__(parser)
            self.copyFrom(ctx)

        def interp(self):
            return self.getTypedRuleContext(HimarkParser.InterpContext,0)


        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterInterpPart" ):
                listener.enterInterpPart(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitInterpPart" ):
                listener.exitInterpPart(self)


    class LoneBracePartContext(PartContext):

        def __init__(self, parser, ctx:ParserRuleContext): # actually a HimarkParser.PartContext
            super().__init__(parser)
            self.copyFrom(ctx)

        def TMPL_LBRACE(self):
            return self.getToken(HimarkParser.TMPL_LBRACE, 0)

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterLoneBracePart" ):
                listener.enterLoneBracePart(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitLoneBracePart" ):
                listener.exitLoneBracePart(self)


    class EscPartContext(PartContext):

        def __init__(self, parser, ctx:ParserRuleContext): # actually a HimarkParser.PartContext
            super().__init__(parser)
            self.copyFrom(ctx)

        def TMPL_ESC(self):
            return self.getToken(HimarkParser.TMPL_ESC, 0)

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterEscPart" ):
                listener.enterEscPart(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitEscPart" ):
                listener.exitEscPart(self)



    def part(self):

        localctx = HimarkParser.PartContext(self, self._ctx, self.state)
        self.enterRule(localctx, 34, self.RULE_part)
        try:
            self.state = 204
            self._errHandler.sync(self)
            token = self._input.LA(1)
            if token in [32]:
                localctx = HimarkParser.TextPartContext(self, localctx)
                self.enterOuterAlt(localctx, 1)
                self.state = 200
                self.match(HimarkParser.TMPL_TEXT)
                pass
            elif token in [30]:
                localctx = HimarkParser.EscPartContext(self, localctx)
                self.enterOuterAlt(localctx, 2)
                self.state = 201
                self.match(HimarkParser.TMPL_ESC)
                pass
            elif token in [31]:
                localctx = HimarkParser.LoneBracePartContext(self, localctx)
                self.enterOuterAlt(localctx, 3)
                self.state = 202
                self.match(HimarkParser.TMPL_LBRACE)
                pass
            elif token in [29]:
                localctx = HimarkParser.InterpPartContext(self, localctx)
                self.enterOuterAlt(localctx, 4)
                self.state = 203
                self.interp()
                pass
            else:
                raise NoViableAltException(self)

        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class InterpContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def MOUST_OPEN(self):
            return self.getToken(HimarkParser.MOUST_OPEN, 0)

        def CAPTURE(self):
            return self.getToken(HimarkParser.CAPTURE, 0)

        def MOUST_CLOSE(self):
            return self.getToken(HimarkParser.MOUST_CLOSE, 0)

        def getRuleIndex(self):
            return HimarkParser.RULE_interp

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterInterp" ):
                listener.enterInterp(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitInterp" ):
                listener.exitInterp(self)




    def interp(self):

        localctx = HimarkParser.InterpContext(self, self._ctx, self.state)
        self.enterRule(localctx, 36, self.RULE_interp)
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 206
            self.match(HimarkParser.MOUST_OPEN)
            self.state = 207
            self.match(HimarkParser.CAPTURE)
            self.state = 208
            self.match(HimarkParser.MOUST_CLOSE)
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx





