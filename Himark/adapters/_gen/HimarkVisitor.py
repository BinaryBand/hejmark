# Generated from grammar/Himark.g4 by ANTLR 4.13.2
from antlr4 import *
if "." in __name__:
    from .HimarkParser import HimarkParser
else:
    from HimarkParser import HimarkParser

# This class defines a complete generic visitor for a parse tree produced by HimarkParser.

class HimarkVisitor(ParseTreeVisitor):

    # Visit a parse tree produced by HimarkParser#query.
    def visitQuery(self, ctx:HimarkParser.QueryContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by HimarkParser#universe.
    def visitUniverse(self, ctx:HimarkParser.UniverseContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by HimarkParser#RangeMember.
    def visitRangeMember(self, ctx:HimarkParser.RangeMemberContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by HimarkParser#SubtractMember.
    def visitSubtractMember(self, ctx:HimarkParser.SubtractMemberContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by HimarkParser#FoldMember.
    def visitFoldMember(self, ctx:HimarkParser.FoldMemberContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by HimarkParser#FaceMember.
    def visitFaceMember(self, ctx:HimarkParser.FaceMemberContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by HimarkParser#face.
    def visitFace(self, ctx:HimarkParser.FaceContext):
        return self.visitChildren(ctx)



del HimarkParser