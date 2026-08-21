with Ada.Strings.Unbounded;
with Ada.Text_IO;

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
         R : constant Tokenize_Result := Tokenize ("sin(pi+$X)");
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
           (Format_Dump (R.Tokens (5)) = "1:8 VARIABLE $X",
            "sin-dump-5");
         Require
           (Format_Dump (R.Tokens (6)) = "1:10 RPAREN )", "sin-dump-6");
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
         R : constant Tokenize_Result := Tokenize ("$VAR1");
      begin
         Require (not R.Had_Errors, "var: no errors");
         Require_Token
           (R.Tokens (1), Variable, "$VAR1", 1, 1, "var");
      end;

      declare
         R : constant Tokenize_Result := Tokenize ("2%3");
      begin
         Require_Token (R.Tokens (2), Percent, "%", 1, 2, "percent");
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
           (To_String (R.Diagnostics (1).Message)
            = "unexpected character '@'",
            "bad: at message");
         Require
           (To_String (R.Diagnostics (2).Message)
            = "unknown identifier 'foo'",
            "bad: foo message");
      end;

      declare
         R : constant Tokenize_Result := Tokenize ("log10");
      begin
         Require (R.Had_Errors, "log10: error");
         if R.Diagnostics'Length > 0 then
            Require
              (To_String (R.Diagnostics (1).Message)
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
         Require (R.Had_Errors, "comma: error");
      end;
   end Run;

end Expr_Tokenizer_Tests;
