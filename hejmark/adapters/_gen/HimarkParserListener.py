# Generated from HimarkParser.g4 by ANTLR 4.13.2
from antlr4 import *
if "." in __name__:
    from .HimarkParser import HimarkParser
else:
    from HimarkParser import HimarkParser

# This class defines a complete listener for a parse tree produced by HimarkParser.
class HimarkParserListener(ParseTreeListener):

    # Enter a parse tree produced by HimarkParser#script.
    def enterScript(self, ctx:HimarkParser.ScriptContext):
        pass

    # Exit a parse tree produced by HimarkParser#script.
    def exitScript(self, ctx:HimarkParser.ScriptContext):
        pass


    # Enter a parse tree produced by HimarkParser#line.
    def enterLine(self, ctx:HimarkParser.LineContext):
        pass

    # Exit a parse tree produced by HimarkParser#line.
    def exitLine(self, ctx:HimarkParser.LineContext):
        pass


    # Enter a parse tree produced by HimarkParser#UniDecl.
    def enterUniDecl(self, ctx:HimarkParser.UniDeclContext):
        pass

    # Exit a parse tree produced by HimarkParser#UniDecl.
    def exitUniDecl(self, ctx:HimarkParser.UniDeclContext):
        pass


    # Enter a parse tree produced by HimarkParser#DefDecl.
    def enterDefDecl(self, ctx:HimarkParser.DefDeclContext):
        pass

    # Exit a parse tree produced by HimarkParser#DefDecl.
    def exitDefDecl(self, ctx:HimarkParser.DefDeclContext):
        pass


    # Enter a parse tree produced by HimarkParser#param.
    def enterParam(self, ctx:HimarkParser.ParamContext):
        pass

    # Exit a parse tree produced by HimarkParser#param.
    def exitParam(self, ctx:HimarkParser.ParamContext):
        pass


    # Enter a parse tree produced by HimarkParser#statement.
    def enterStatement(self, ctx:HimarkParser.StatementContext):
        pass

    # Exit a parse tree produced by HimarkParser#statement.
    def exitStatement(self, ctx:HimarkParser.StatementContext):
        pass


    # Enter a parse tree produced by HimarkParser#QueryStep.
    def enterQueryStep(self, ctx:HimarkParser.QueryStepContext):
        pass

    # Exit a parse tree produced by HimarkParser#QueryStep.
    def exitQueryStep(self, ctx:HimarkParser.QueryStepContext):
        pass


    # Enter a parse tree produced by HimarkParser#TemplateStep.
    def enterTemplateStep(self, ctx:HimarkParser.TemplateStepContext):
        pass

    # Exit a parse tree produced by HimarkParser#TemplateStep.
    def exitTemplateStep(self, ctx:HimarkParser.TemplateStepContext):
        pass


    # Enter a parse tree produced by HimarkParser#expr.
    def enterExpr(self, ctx:HimarkParser.ExprContext):
        pass

    # Exit a parse tree produced by HimarkParser#expr.
    def exitExpr(self, ctx:HimarkParser.ExprContext):
        pass


    # Enter a parse tree produced by HimarkParser#unit.
    def enterUnit(self, ctx:HimarkParser.UnitContext):
        pass

    # Exit a parse tree produced by HimarkParser#unit.
    def exitUnit(self, ctx:HimarkParser.UnitContext):
        pass


    # Enter a parse tree produced by HimarkParser#UniverseBase.
    def enterUniverseBase(self, ctx:HimarkParser.UniverseBaseContext):
        pass

    # Exit a parse tree produced by HimarkParser#UniverseBase.
    def exitUniverseBase(self, ctx:HimarkParser.UniverseBaseContext):
        pass


    # Enter a parse tree produced by HimarkParser#ReferenceBase.
    def enterReferenceBase(self, ctx:HimarkParser.ReferenceBaseContext):
        pass

    # Exit a parse tree produced by HimarkParser#ReferenceBase.
    def exitReferenceBase(self, ctx:HimarkParser.ReferenceBaseContext):
        pass


    # Enter a parse tree produced by HimarkParser#OperandBase.
    def enterOperandBase(self, ctx:HimarkParser.OperandBaseContext):
        pass

    # Exit a parse tree produced by HimarkParser#OperandBase.
    def exitOperandBase(self, ctx:HimarkParser.OperandBaseContext):
        pass


    # Enter a parse tree produced by HimarkParser#exponent.
    def enterExponent(self, ctx:HimarkParser.ExponentContext):
        pass

    # Exit a parse tree produced by HimarkParser#exponent.
    def exitExponent(self, ctx:HimarkParser.ExponentContext):
        pass


    # Enter a parse tree produced by HimarkParser#pipeline.
    def enterPipeline(self, ctx:HimarkParser.PipelineContext):
        pass

    # Exit a parse tree produced by HimarkParser#pipeline.
    def exitPipeline(self, ctx:HimarkParser.PipelineContext):
        pass


    # Enter a parse tree produced by HimarkParser#pipeItem.
    def enterPipeItem(self, ctx:HimarkParser.PipeItemContext):
        pass

    # Exit a parse tree produced by HimarkParser#pipeItem.
    def exitPipeItem(self, ctx:HimarkParser.PipeItemContext):
        pass


    # Enter a parse tree produced by HimarkParser#universe.
    def enterUniverse(self, ctx:HimarkParser.UniverseContext):
        pass

    # Exit a parse tree produced by HimarkParser#universe.
    def exitUniverse(self, ctx:HimarkParser.UniverseContext):
        pass


    # Enter a parse tree produced by HimarkParser#RangeMember.
    def enterRangeMember(self, ctx:HimarkParser.RangeMemberContext):
        pass

    # Exit a parse tree produced by HimarkParser#RangeMember.
    def exitRangeMember(self, ctx:HimarkParser.RangeMemberContext):
        pass


    # Enter a parse tree produced by HimarkParser#FinalMember.
    def enterFinalMember(self, ctx:HimarkParser.FinalMemberContext):
        pass

    # Exit a parse tree produced by HimarkParser#FinalMember.
    def exitFinalMember(self, ctx:HimarkParser.FinalMemberContext):
        pass


    # Enter a parse tree produced by HimarkParser#SubtractMember.
    def enterSubtractMember(self, ctx:HimarkParser.SubtractMemberContext):
        pass

    # Exit a parse tree produced by HimarkParser#SubtractMember.
    def exitSubtractMember(self, ctx:HimarkParser.SubtractMemberContext):
        pass


    # Enter a parse tree produced by HimarkParser#SegmentsMember.
    def enterSegmentsMember(self, ctx:HimarkParser.SegmentsMemberContext):
        pass

    # Exit a parse tree produced by HimarkParser#SegmentsMember.
    def exitSegmentsMember(self, ctx:HimarkParser.SegmentsMemberContext):
        pass


    # Enter a parse tree produced by HimarkParser#segment.
    def enterSegment(self, ctx:HimarkParser.SegmentContext):
        pass

    # Exit a parse tree produced by HimarkParser#segment.
    def exitSegment(self, ctx:HimarkParser.SegmentContext):
        pass


    # Enter a parse tree produced by HimarkParser#face.
    def enterFace(self, ctx:HimarkParser.FaceContext):
        pass

    # Exit a parse tree produced by HimarkParser#face.
    def exitFace(self, ctx:HimarkParser.FaceContext):
        pass


    # Enter a parse tree produced by HimarkParser#template.
    def enterTemplate(self, ctx:HimarkParser.TemplateContext):
        pass

    # Exit a parse tree produced by HimarkParser#template.
    def exitTemplate(self, ctx:HimarkParser.TemplateContext):
        pass


    # Enter a parse tree produced by HimarkParser#TextPart.
    def enterTextPart(self, ctx:HimarkParser.TextPartContext):
        pass

    # Exit a parse tree produced by HimarkParser#TextPart.
    def exitTextPart(self, ctx:HimarkParser.TextPartContext):
        pass


    # Enter a parse tree produced by HimarkParser#EscPart.
    def enterEscPart(self, ctx:HimarkParser.EscPartContext):
        pass

    # Exit a parse tree produced by HimarkParser#EscPart.
    def exitEscPart(self, ctx:HimarkParser.EscPartContext):
        pass


    # Enter a parse tree produced by HimarkParser#LoneBracePart.
    def enterLoneBracePart(self, ctx:HimarkParser.LoneBracePartContext):
        pass

    # Exit a parse tree produced by HimarkParser#LoneBracePart.
    def exitLoneBracePart(self, ctx:HimarkParser.LoneBracePartContext):
        pass


    # Enter a parse tree produced by HimarkParser#InterpPart.
    def enterInterpPart(self, ctx:HimarkParser.InterpPartContext):
        pass

    # Exit a parse tree produced by HimarkParser#InterpPart.
    def exitInterpPart(self, ctx:HimarkParser.InterpPartContext):
        pass


    # Enter a parse tree produced by HimarkParser#interp.
    def enterInterp(self, ctx:HimarkParser.InterpContext):
        pass

    # Exit a parse tree produced by HimarkParser#interp.
    def exitInterp(self, ctx:HimarkParser.InterpContext):
        pass



del HimarkParser