with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with Expr_Preprocessor;
with Expr_Parser;
with Expr_Tokenizer;

package body Expr_Parser_Tests is

   use Ada.Strings.Unbounded;
   use type Expr_Parser.Node_Kind;
   use type Expr_Parser.Node_Access;

   procedure Run (Failed : in out Boolean) is

      procedure Require (Cond : Boolean; Message : String) is
      begin
         if not Cond then
            Failed := True;
            Ada.Text_IO.Put_Line ("FAIL: " & Message);
         end if;
      end Require;

      function Parse_Source
        (Source : String) return Expr_Parser.Parse_Result
      is
         Tok : constant Expr_Tokenizer.Tokenize_Result :=
           Expr_Tokenizer.Tokenize (Source);
      begin
         Require (not Tok.Had_Errors, "tokenize ok for: " & Source);
         return Expr_Parser.Parse (Tok.Tokens.all);
      end Parse_Source;

      procedure Require_Kind
        (N : Expr_Parser.Node_Access;
         Kind : Expr_Parser.Node_Kind;
         Msg  : String)
      is
      begin
         Require (N /= null, Msg & ": non-null");
         if N /= null then
            Require (N.Kind = Kind, Msg & ": kind");
         end if;
      end Require_Kind;

      procedure Require_Lex
        (N : Expr_Parser.Node_Access; Lex : String; Msg : String)
      is
      begin
         Require (N /= null, Msg & ": non-null");
         if N /= null then
            Require (To_String (N.Lexeme) = Lex, Msg & ": lexeme");
         end if;
      end Require_Lex;

   begin
      --  1+2*3 → add(1, mul(2, 3))
      declare
         R : constant Expr_Parser.Parse_Result := Parse_Source ("1+2*3");
      begin
         Require (not R.Had_Error, "add-mul: ok");
         Require_Kind (R.Root, Expr_Parser.Add_Node, "add-mul-root");
         if R.Root /= null then
            Require_Kind (R.Root.Left, Expr_Parser.Number_Node, "add-mul-l");
            Require_Lex (R.Root.Left, "1", "add-mul-l");
            Require_Kind (R.Root.Right, Expr_Parser.Mul_Node, "add-mul-r");
            if R.Root.Right /= null then
               Require_Lex (R.Root.Right.Left, "2", "add-mul-rl");
               Require_Lex (R.Root.Right.Right, "3", "add-mul-rr");
            end if;
         end if;
      end;

      --  (1+2)*3 → mul(add(1, 2), 3)
      declare
         R : constant Expr_Parser.Parse_Result := Parse_Source ("(1+2)*3");
      begin
         Require (not R.Had_Error, "parens: ok");
         Require_Kind (R.Root, Expr_Parser.Mul_Node, "parens-root");
         if R.Root /= null then
            Require_Kind (R.Root.Left, Expr_Parser.Add_Node, "parens-l");
            Require_Lex (R.Root.Right, "3", "parens-r");
         end if;
      end;

      --  2^3^2 → pow(2, pow(3, 2))
      declare
         R : constant Expr_Parser.Parse_Result := Parse_Source ("2^3^2");
      begin
         Require (not R.Had_Error, "pow: ok");
         Require_Kind (R.Root, Expr_Parser.Pow_Node, "pow-root");
         if R.Root /= null then
            Require_Lex (R.Root.Left, "2", "pow-l");
            Require_Kind (R.Root.Right, Expr_Parser.Pow_Node, "pow-r");
            if R.Root.Right /= null then
               Require_Lex (R.Root.Right.Left, "3", "pow-rl");
               Require_Lex (R.Root.Right.Right, "2", "pow-rr");
            end if;
         end if;
      end;

      --  -2^2 → neg(pow(2, 2))
      declare
         R : constant Expr_Parser.Parse_Result := Parse_Source ("-2^2");
      begin
         Require (not R.Had_Error, "unary-pow: ok");
         Require_Kind (R.Root, Expr_Parser.UMinus_Node, "unary-pow-root");
         if R.Root /= null then
            Require_Kind (R.Root.Left, Expr_Parser.Pow_Node, "unary-pow-c");
         end if;
      end;

      --  8/4*2 → mul(div(8, 4), 2)
      declare
         R : constant Expr_Parser.Parse_Result := Parse_Source ("8/4*2");
      begin
         Require (not R.Had_Error, "muldiv: ok");
         Require_Kind (R.Root, Expr_Parser.Mul_Node, "muldiv-root");
         if R.Root /= null then
            Require_Kind (R.Root.Left, Expr_Parser.Div_Node, "muldiv-l");
            Require_Lex (R.Root.Right, "2", "muldiv-r");
         end if;
      end;

      declare
         Tok : constant Expr_Tokenizer.Tokenize_Result :=
           Expr_Tokenizer.Tokenize ("2%3");
         R   : Expr_Parser.Parse_Result;
      begin
         Require (Tok.Had_Errors, "percent-tok: lex error");
         R := Expr_Parser.Parse (Tok.Tokens.all);
         Require (R.Had_Error, "percent: err");
         Require (R.Root = null, "percent: no root");
      end;

      declare
         R : constant Expr_Parser.Parse_Result :=
           Parse_Source ("sin(pi+1)");
      begin
         Require (not R.Had_Error, "call: ok");
         Require_Kind (R.Root, Expr_Parser.Call_Node, "call-root");
         Require_Lex (R.Root, "sin", "call-name");
         if R.Root /= null then
            Require_Kind (R.Root.Left, Expr_Parser.Add_Node, "call-arg");
         end if;
      end;

      declare
         R : constant Expr_Parser.Parse_Result := Parse_Source ("e^(-1)");
      begin
         Require (not R.Had_Error, "exp-neg: ok");
         Require_Kind (R.Root, Expr_Parser.Pow_Node, "exp-neg-root");
      end;

      declare
         R : constant Expr_Parser.Parse_Result :=
           Parse_Source ("sinh(cosh(1))");
      begin
         Require (not R.Had_Error, "nested-call: ok");
         Require_Kind (R.Root, Expr_Parser.Call_Node, "nested-root");
         Require_Lex (R.Root, "sinh", "nested-name");
      end;

      declare
         R : constant Expr_Parser.Parse_Result := Parse_Source ("1*-2");
      begin
         Require (not R.Had_Error, "unary-after: ok");
         Require_Kind (R.Root, Expr_Parser.Mul_Node, "unary-after-root");
         if R.Root /= null then
            Require_Kind
              (R.Root.Right, Expr_Parser.UMinus_Node, "unary-after-r");
         end if;
      end;

      --  Negative paths
      declare
         R : constant Expr_Parser.Parse_Result := Parse_Source ("");
      begin
         Require (R.Had_Error, "empty: err");
         Require (R.Root = null, "empty: no root");
      end;

      declare
         R : constant Expr_Parser.Parse_Result := Parse_Source ("1+2 3");
      begin
         Require (R.Had_Error, "trailing: err");
      end;

      declare
         R : constant Expr_Parser.Parse_Result := Parse_Source ("(1+2");
      begin
         Require (R.Had_Error, "unmatched-l: err");
      end;

      declare
         R : constant Expr_Parser.Parse_Result := Parse_Source ("1+2)");
      begin
         Require (R.Had_Error, "unmatched-r: err");
      end;

      declare
         R : constant Expr_Parser.Parse_Result := Parse_Source ("sin 1");
      begin
         Require (R.Had_Error, "sin-no-paren: err");
      end;

      declare
         R : constant Expr_Parser.Parse_Result := Parse_Source ("sin()");
      begin
         Require (R.Had_Error, "sin-empty: err");
      end;

      declare
         R : constant Expr_Parser.Parse_Result := Parse_Source ("1+");
      begin
         Require (R.Had_Error, "missing-rhs: err");
      end;

      declare
         R : constant Expr_Parser.Parse_Result := Parse_Source ("2 pi");
      begin
         Require (R.Had_Error, "juxtapose: err");
      end;

      declare
         B : constant Expr_Preprocessor.Binding_Array :=
           [1 =>
              (Name  => To_Unbounded_String ("$X"),
               Value => To_Unbounded_String ("1+"))];
         Prep : constant Expr_Preprocessor.Preprocess_Result :=
           Expr_Preprocessor.Preprocess ("$X", B);
         Tok  : constant Expr_Tokenizer.Tokenize_Result :=
           Expr_Tokenizer.Tokenize
             (To_String (Prep.Text), Prep.Origins);
         R    : constant Expr_Parser.Parse_Result :=
           Expr_Parser.Parse (Tok.Tokens.all);
      begin
         Require (not Prep.Had_Error, "var-parse-prep: ok");
         Require (R.Had_Error, "var-parse: err");
         Require (R.From_Var, "var-parse: from-var");
         Require
           (To_String (R.Var_Name) = "$X",
            "var-parse: var-name");
      end;

      --  Emitters
      declare
         R : constant Expr_Parser.Parse_Result := Parse_Source ("1+2*3");
         Expected : constant String :=
           "flowchart TD"
           & ASCII.LF
           & "  n1[""+""]"
           & ASCII.LF
           & "  n2[""1""]"
           & ASCII.LF
           & "  n3[""*""]"
           & ASCII.LF
           & "  n4[""2""]"
           & ASCII.LF
           & "  n5[""3""]"
           & ASCII.LF
           & "  n1 --> n2"
           & ASCII.LF
           & "  n1 --> n3"
           & ASCII.LF
           & "  n3 --> n4"
           & ASCII.LF
           & "  n3 --> n5";
         Got : constant String := Expr_Parser.Format_Mermaid (R.Root);
      begin
         Require (Got = Expected, "mermaid-add-mul");
      end;

      declare
         R : constant Expr_Parser.Parse_Result := Parse_Source ("(1+2)*3");
         Expected : constant String :=
           "flowchart TD"
           & ASCII.LF
           & "  n1[""*""]"
           & ASCII.LF
           & "  n2[""+""]"
           & ASCII.LF
           & "  n3[""1""]"
           & ASCII.LF
           & "  n4[""2""]"
           & ASCII.LF
           & "  n5[""3""]"
           & ASCII.LF
           & "  n1 --> n2"
           & ASCII.LF
           & "  n1 --> n5"
           & ASCII.LF
           & "  n2 --> n3"
           & ASCII.LF
           & "  n2 --> n4";
         Got : constant String := Expr_Parser.Format_Mermaid (R.Root);
      begin
         Require (Got = Expected, "mermaid-parens");
      end;

      declare
         R : constant Expr_Parser.Parse_Result := Parse_Source ("1+2*3");
         M : constant String := Expr_Parser.Format_Mermaid (R.Root);
         Md : constant String := Expr_Parser.Format_Markdown (R.Root);
         Dot : constant String := Expr_Parser.Format_Dot (R.Root);
         Svg : constant String := Expr_Parser.Format_Svg (R.Root);
      begin
         Require
           (Md =
              "# Syntax tree"
              & ASCII.LF
              & ASCII.LF
              & "```mermaid"
              & ASCII.LF
              & M
              & ASCII.LF
              & "```",
            "md-wraps-mermaid");
         Require
           (Ada.Strings.Fixed.Index (Dot, "digraph syntaxtree") = 1,
            "dot-header");
         Require
           (Ada.Strings.Fixed.Index (Dot, "n1 [label=""+""];") > 0,
            "dot-n1");
         Require
           (Ada.Strings.Fixed.Index (Dot, "n1 -> n2;") > 0, "dot-edge");
         Require
           (Ada.Strings.Fixed.Index (Svg, "<svg") = 1, "svg-root");
         Require
           (Ada.Strings.Fixed.Index (Svg, ">+<") > 0
            or else Ada.Strings.Fixed.Index (Svg, ">+</text>") > 0
            or else Ada.Strings.Fixed.Index (Svg, ">+") > 0,
            "svg-plus");
         Require (Ada.Strings.Fixed.Index (Svg, ">*</text>") > 0
            or else Ada.Strings.Fixed.Index (Svg, ">*") > 0,
            "svg-star");
         Require (Ada.Strings.Fixed.Index (Svg, ">1</text>") > 0, "svg-1");
         Require (Ada.Strings.Fixed.Index (Svg, ">2</text>") > 0, "svg-2");
         Require (Ada.Strings.Fixed.Index (Svg, ">3</text>") > 0, "svg-3");
      end;
   end Run;

end Expr_Parser_Tests;
