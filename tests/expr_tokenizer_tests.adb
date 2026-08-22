with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Eml.Diagnostics;

with Expr_Preprocessor;
with Expr_Tokenizer;

package body Expr_Tokenizer_Tests is

   use Ada.Strings.Unbounded;
   use Expr_Tokenizer;

   procedure Run (Failed : in out Boolean) is

      procedure Require (Cond : Boolean; Message : String) is
      begin
         if not Cond then
            Failed := True;
            Ada.Text_IO.Put_Line ("FAIL: " & Message);
         end if;
      end Require;

      procedure Require_Token
        (T      : Token;
         Kind   : Token_Kind;
         Lexeme : String;
         Line   : Positive;
         Column : Positive;
         Label  : String)
      is
      begin
         Require (T.Kind = Kind, Label & ": kind");
         Require (To_String (T.Lexeme) = Lexeme, Label & ": lexeme");
         Require (T.Line = Line, Label & ": line");
         Require (T.Column = Column, Label & ": column");
      end Require_Token;

      function Format_Dump (T : Token) return String is
         function Trim (N : Positive) return String is
            S : constant String := Positive'Image (N);
         begin
            if S (S'First) = ' ' then
               return S (S'First + 1 .. S'Last);
            end if;
            return S;
         end Trim;
      begin
         return Trim (T.Line)
           & ":"
           & Trim (T.Column)
           & " "
           & Kind_Name (T.Kind)
           & " "
           & To_String (T.Lexeme);
      end Format_Dump;

   begin
      declare
         R : constant Tokenize_Result := Tokenize ("1+2*3");
      begin
         Require (not R.Had_Errors, "arith: no errors");
         Require (R.Tokens'Length = 5, "arith: count");
         if R.Tokens'Length >= 5 then
            Require_Token (R.Tokens (1), Number, "1", 1, 1, "arith-1");
            Require_Token (R.Tokens (2), Plus, "+", 1, 2, "arith-2");
            Require_Token (R.Tokens (3), Number, "2", 1, 3, "arith-3");
            Require_Token (R.Tokens (4), Star, "*", 1, 4, "arith-4");
            Require_Token (R.Tokens (5), Number, "3", 1, 5, "arith-5");
         end if;
      end;

      declare
         R : constant Tokenize_Result := Tokenize ("3.14");
      begin
         Require (not R.Had_Errors, "float: no errors");
         Require_Token (R.Tokens (1), Number, "3.14", 1, 1, "float");
      end;

      declare
         R : constant Tokenize_Result := Tokenize ("1.2e-3");
      begin
         Require (not R.Had_Errors, "sci: no errors");
         Require_Token (R.Tokens (1), Number, "1.2e-3", 1, 1, "sci");
      end;

      declare
         R : constant Tokenize_Result := Tokenize ("sin(pi+1)");
      begin
         Require (not R.Had_Errors, "sin: no errors");
         Require (R.Tokens'Length = 6, "sin: count");
         Require
           (Format_Dump (R.Tokens (1)) = "1:1 FUNCTION sin",
            "sin-dump-1");
         Require
           (Format_Dump (R.Tokens (2)) = "1:4 LPAREN (", "sin-dump-2");
         Require
           (Format_Dump (R.Tokens (3)) = "1:5 CONSTANT pi",
            "sin-dump-3");
         Require
           (Format_Dump (R.Tokens (4)) = "1:7 PLUS +", "sin-dump-4");
         Require
           (Format_Dump (R.Tokens (5)) = "1:8 NUMBER 1",
            "sin-dump-5");
         Require
           (Format_Dump (R.Tokens (6)) = "1:9 RPAREN )", "sin-dump-6");
      end;

      declare
         R : constant Tokenize_Result := Tokenize ("e i phi");
      begin
         Require (not R.Had_Errors, "consts: no errors");
         Require_Token (R.Tokens (1), Constant_Name, "e", 1, 1, "e");
         Require_Token (R.Tokens (2), Constant_Name, "i", 1, 3, "i");
         Require_Token (R.Tokens (3), Constant_Name, "phi", 1, 5, "phi");
      end;

      declare
         R : constant Tokenize_Result := Tokenize ("$X");
      begin
         Require (R.Had_Errors, "dollar: error");
         Require (R.Tokens'Length = 0, "dollar: no valid tokens");
         Require (R.Diagnostics'Length >= 1, "dollar: diag count");
         if R.Diagnostics'Length >= 1 then
            Require (R.Diagnostics (1).Line = 1, "dollar: diag line");
            Require (R.Diagnostics (1).Column = 1, "dollar: diag column");
            Require
              (Eml.Diagnostics.Message
                 (R.Diagnostics (1).Id,
                  To_String (R.Diagnostics (1).Param1))
               = "unexpected character '$'",
               "dollar: diag message");
         end if;
      end;

      declare
         R : constant Tokenize_Result := Tokenize ("2%3");
      begin
         Require (R.Had_Errors, "percent: error");
         Require (R.Tokens'Length = 2, "percent: valid token count");
         Require (R.Diagnostics'Length = 1, "percent: diag count");
         if R.Tokens'Length >= 2 then
            Require_Token (R.Tokens (1), Number, "2", 1, 1, "percent-num");
            Require_Token (R.Tokens (2), Number, "3", 1, 3, "percent-denom");
         end if;
         if R.Diagnostics'Length >= 1 then
            Require (R.Diagnostics (1).Line = 1, "percent: diag line");
            Require (R.Diagnostics (1).Column = 2, "percent: diag column");
            Require
              (Eml.Diagnostics.Message
                 (R.Diagnostics (1).Id,
                  To_String (R.Diagnostics (1).Param1))
               = "unexpected character '%'",
               "percent: diag message");
         end if;
      end;

      declare
         R : constant Tokenize_Result := Tokenize ("2^3");
      begin
         Require_Token (R.Tokens (2), Caret, "^", 1, 2, "caret");
      end;

      declare
         R : constant Tokenize_Result :=
           Tokenize ("sinh(cosh(tanh(1)))");
      begin
         Require (not R.Had_Errors, "hyperbolic: no errors");
         Require_Token
           (R.Tokens (1), Function_Name, "sinh", 1, 1, "sinh");
         Require_Token
           (R.Tokens (3), Function_Name, "cosh", 1, 6, "cosh");
         Require_Token
           (R.Tokens (5), Function_Name, "tanh", 1, 11, "tanh");
      end;

      declare
         R : constant Tokenize_Result := Tokenize ("1" & ASCII.LF & "+2");
      begin
         Require (not R.Had_Errors, "newline: no errors");
         Require_Token (R.Tokens (1), Number, "1", 1, 1, "nl-1");
         Require_Token (R.Tokens (2), Plus, "+", 2, 1, "nl-2");
         Require_Token (R.Tokens (3), Number, "2", 2, 2, "nl-3");
      end;

      declare
         R : constant Tokenize_Result := Tokenize ("");
      begin
         Require (not R.Had_Errors, "empty: no errors");
         Require (R.Tokens'Length = 0, "empty: count");
      end;

      --  Recovery: continue after invalid tokens
      declare
         R : constant Tokenize_Result := Tokenize ("1+@2 foo");
      begin
         Require (R.Had_Errors, "bad: had errors");
         Require (R.Diagnostics'Length = 2, "bad: diag count");
         Require (R.Tokens'Length = 3, "bad: valid tokens");
         Require_Token (R.Tokens (1), Number, "1", 1, 1, "bad-1");
         Require_Token (R.Tokens (2), Plus, "+", 1, 2, "bad-2");
         Require_Token (R.Tokens (3), Number, "2", 1, 4, "bad-3");
         Require
           (Eml.Diagnostics.Message
              (R.Diagnostics (1).Id,
               To_String (R.Diagnostics (1).Param1))
            = "unexpected character '@'",
            "bad: at message");
         Require
           (Eml.Diagnostics.Message
              (R.Diagnostics (2).Id,
               To_String (R.Diagnostics (2).Param1))
            = "unknown identifier 'foo'",
            "bad: foo message");
      end;

      declare
         R : constant Tokenize_Result := Tokenize ("log10");
      begin
         Require (R.Had_Errors, "log10: error");
         if R.Diagnostics'Length > 0 then
            Require
              (Eml.Diagnostics.Message
                 (R.Diagnostics (1).Id,
                  To_String (R.Diagnostics (1).Param1))
               = "unknown identifier 'log10'",
               "log10: message");
         end if;
      end;

      declare
         R : constant Tokenize_Result := Tokenize ("Tan");
      begin
         Require (R.Had_Errors, "Tan: error");
      end;

      declare
         R : constant Tokenize_Result := Tokenize (".");
      begin
         Require (R.Had_Errors, "dot: error");
      end;

      declare
         R : constant Tokenize_Result := Tokenize (",");
      begin
         Require (not R.Had_Errors, "comma: ok");
         Require (R.Tokens'Length = 1, "comma: count");
         Require_Token (R.Tokens (1), Comma, ",", 1, 1, "comma");
      end;

      declare
         B : constant Expr_Preprocessor.Binding_Array :=
           [1 =>
              (Name  => To_Unbounded_String ("$X"),
               Value => To_Unbounded_String ("1"))];
         Prep : constant Expr_Preprocessor.Preprocess_Result :=
           Expr_Preprocessor.Preprocess ("sin(pi+$X)", B);
         R    : constant Tokenize_Result :=
           Tokenize (To_String (Prep.Text), Prep.Origins);
      begin
         Require (not R.Had_Errors, "preproc-tok: no errors");
         Require (R.Tokens'Length = 6, "preproc-tok: count");
         Require
           (Format_Dump (R.Tokens (5)) = "1:8 NUMBER 1",
            "preproc-tok: substituted");
         Require (R.Tokens (5).From_Var, "preproc-tok: from-var");
      end;

      declare
         B : constant Expr_Preprocessor.Binding_Array :=
           [1 =>
              (Name  => To_Unbounded_String ("$Y"),
               Value => To_Unbounded_String ("@"))];
         Prep : constant Expr_Preprocessor.Preprocess_Result :=
           Expr_Preprocessor.Preprocess ("$Y", B);
         R    : constant Tokenize_Result :=
           Tokenize (To_String (Prep.Text), Prep.Origins);
      begin
         Require (R.Had_Errors, "var-lex: error");
         Require (R.Diagnostics'Length = 1, "var-lex: diag count");
         Require (R.Diagnostics (1).From_Var, "var-lex: from-var");
         Require
           (To_String (R.Diagnostics (1).Var_Name) = "$Y",
            "var-lex: var-name");
         Require
           (Eml.Diagnostics.Message
              (R.Diagnostics (1).Id,
               To_String (R.Diagnostics (1).Param1))
            = "unexpected character '@'",
            "var-lex: message");
      end;
   end Run;

end Expr_Tokenizer_Tests;
