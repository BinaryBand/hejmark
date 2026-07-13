# Generated from grammar/Himark.g4 by ANTLR 4.13.2
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
        4,1,8,43,2,0,7,0,2,1,7,1,2,2,7,2,2,3,7,3,1,0,4,0,10,8,0,11,0,12,
        0,11,1,0,1,0,1,1,1,1,1,1,1,1,5,1,20,8,1,10,1,12,1,23,9,1,3,1,25,
        8,1,1,1,1,1,1,2,1,2,1,2,1,2,1,2,1,2,1,2,3,2,36,8,2,1,3,4,3,39,8,
        3,11,3,12,3,40,1,3,0,0,4,0,2,4,6,0,1,1,0,6,8,45,0,9,1,0,0,0,2,15,
        1,0,0,0,4,35,1,0,0,0,6,38,1,0,0,0,8,10,3,2,1,0,9,8,1,0,0,0,10,11,
        1,0,0,0,11,9,1,0,0,0,11,12,1,0,0,0,12,13,1,0,0,0,13,14,5,0,0,1,14,
        1,1,0,0,0,15,24,5,1,0,0,16,21,3,4,2,0,17,18,5,3,0,0,18,20,3,4,2,
        0,19,17,1,0,0,0,20,23,1,0,0,0,21,19,1,0,0,0,21,22,1,0,0,0,22,25,
        1,0,0,0,23,21,1,0,0,0,24,16,1,0,0,0,24,25,1,0,0,0,25,26,1,0,0,0,
        26,27,5,2,0,0,27,3,1,0,0,0,28,29,5,8,0,0,29,30,5,5,0,0,30,36,5,8,
        0,0,31,32,5,4,0,0,32,36,3,2,1,0,33,36,3,2,1,0,34,36,3,6,3,0,35,28,
        1,0,0,0,35,31,1,0,0,0,35,33,1,0,0,0,35,34,1,0,0,0,36,5,1,0,0,0,37,
        39,7,0,0,0,38,37,1,0,0,0,39,40,1,0,0,0,40,38,1,0,0,0,40,41,1,0,0,
        0,41,7,1,0,0,0,5,11,21,24,35,40
    ]

class HimarkParser ( Parser ):

    grammarFileName = "Himark.g4"

    atn = ATNDeserializer().deserialize(serializedATN())

    decisionsToDFA = [ DFA(ds, i) for i, ds in enumerate(atn.decisionToState) ]

    sharedContextCache = PredictionContextCache()

    literalNames = [ "<INVALID>", "'{'", "'}'", "','", "'!'", "'..'", "'.'" ]

    symbolicNames = [ "<INVALID>", "LBRACE", "RBRACE", "COMMA", "BANG", 
                      "RANGE", "DOT", "ESC", "CHAR" ]

    RULE_query = 0
    RULE_universe = 1
    RULE_member = 2
    RULE_face = 3

    ruleNames =  [ "query", "universe", "member", "face" ]

    EOF = Token.EOF
    LBRACE=1
    RBRACE=2
    COMMA=3
    BANG=4
    RANGE=5
    DOT=6
    ESC=7
    CHAR=8

    def __init__(self, input:TokenStream, output:TextIO = sys.stdout):
        super().__init__(input, output)
        self.checkVersion("4.13.2")
        self._interp = ParserATNSimulator(self, self.atn, self.decisionsToDFA, self.sharedContextCache)
        self._predicates = None




    class QueryContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def EOF(self):
            return self.getToken(HimarkParser.EOF, 0)

        def universe(self, i:int=None):
            if i is None:
                return self.getTypedRuleContexts(HimarkParser.UniverseContext)
            else:
                return self.getTypedRuleContext(HimarkParser.UniverseContext,i)


        def getRuleIndex(self):
            return HimarkParser.RULE_query

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitQuery" ):
                return visitor.visitQuery(self)
            else:
                return visitor.visitChildren(self)




    def query(self):

        localctx = HimarkParser.QueryContext(self, self._ctx, self.state)
        self.enterRule(localctx, 0, self.RULE_query)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 9 
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            while True:
                self.state = 8
                self.universe()
                self.state = 11 
                self._errHandler.sync(self)
                _la = self._input.LA(1)
                if not (_la==1):
                    break

            self.state = 13
            self.match(HimarkParser.EOF)
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

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitUniverse" ):
                return visitor.visitUniverse(self)
            else:
                return visitor.visitChildren(self)




    def universe(self):

        localctx = HimarkParser.UniverseContext(self, self._ctx, self.state)
        self.enterRule(localctx, 2, self.RULE_universe)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 15
            self.match(HimarkParser.LBRACE)
            self.state = 24
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            if (((_la) & ~0x3f) == 0 and ((1 << _la) & 466) != 0):
                self.state = 16
                self.member()
                self.state = 21
                self._errHandler.sync(self)
                _la = self._input.LA(1)
                while _la==3:
                    self.state = 17
                    self.match(HimarkParser.COMMA)
                    self.state = 18
                    self.member()
                    self.state = 23
                    self._errHandler.sync(self)
                    _la = self._input.LA(1)



            self.state = 26
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


        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitSubtractMember" ):
                return visitor.visitSubtractMember(self)
            else:
                return visitor.visitChildren(self)


    class FaceMemberContext(MemberContext):

        def __init__(self, parser, ctx:ParserRuleContext): # actually a HimarkParser.MemberContext
            super().__init__(parser)
            self.copyFrom(ctx)

        def face(self):
            return self.getTypedRuleContext(HimarkParser.FaceContext,0)


        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitFaceMember" ):
                return visitor.visitFaceMember(self)
            else:
                return visitor.visitChildren(self)


    class RangeMemberContext(MemberContext):

        def __init__(self, parser, ctx:ParserRuleContext): # actually a HimarkParser.MemberContext
            super().__init__(parser)
            self.copyFrom(ctx)

        def CHAR(self, i:int=None):
            if i is None:
                return self.getTokens(HimarkParser.CHAR)
            else:
                return self.getToken(HimarkParser.CHAR, i)
        def RANGE(self):
            return self.getToken(HimarkParser.RANGE, 0)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitRangeMember" ):
                return visitor.visitRangeMember(self)
            else:
                return visitor.visitChildren(self)


    class FoldMemberContext(MemberContext):

        def __init__(self, parser, ctx:ParserRuleContext): # actually a HimarkParser.MemberContext
            super().__init__(parser)
            self.copyFrom(ctx)

        def universe(self):
            return self.getTypedRuleContext(HimarkParser.UniverseContext,0)


        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitFoldMember" ):
                return visitor.visitFoldMember(self)
            else:
                return visitor.visitChildren(self)



    def member(self):

        localctx = HimarkParser.MemberContext(self, self._ctx, self.state)
        self.enterRule(localctx, 4, self.RULE_member)
        try:
            self.state = 35
            self._errHandler.sync(self)
            la_ = self._interp.adaptivePredict(self._input,3,self._ctx)
            if la_ == 1:
                localctx = HimarkParser.RangeMemberContext(self, localctx)
                self.enterOuterAlt(localctx, 1)
                self.state = 28
                self.match(HimarkParser.CHAR)
                self.state = 29
                self.match(HimarkParser.RANGE)
                self.state = 30
                self.match(HimarkParser.CHAR)
                pass

            elif la_ == 2:
                localctx = HimarkParser.SubtractMemberContext(self, localctx)
                self.enterOuterAlt(localctx, 2)
                self.state = 31
                self.match(HimarkParser.BANG)
                self.state = 32
                self.universe()
                pass

            elif la_ == 3:
                localctx = HimarkParser.FoldMemberContext(self, localctx)
                self.enterOuterAlt(localctx, 3)
                self.state = 33
                self.universe()
                pass

            elif la_ == 4:
                localctx = HimarkParser.FaceMemberContext(self, localctx)
                self.enterOuterAlt(localctx, 4)
                self.state = 34
                self.face()
                pass


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

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitFace" ):
                return visitor.visitFace(self)
            else:
                return visitor.visitChildren(self)




    def face(self):

        localctx = HimarkParser.FaceContext(self, self._ctx, self.state)
        self.enterRule(localctx, 6, self.RULE_face)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 38 
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            while True:
                self.state = 37
                _la = self._input.LA(1)
                if not((((_la) & ~0x3f) == 0 and ((1 << _la) & 448) != 0)):
                    self._errHandler.recoverInline(self)
                else:
                    self._errHandler.reportMatch(self)
                    self.consume()
                self.state = 40 
                self._errHandler.sync(self)
                _la = self._input.LA(1)
                if not ((((_la) & ~0x3f) == 0 and ((1 << _la) & 448) != 0)):
                    break

        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx





