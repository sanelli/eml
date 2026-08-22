--  Tokenize .teml source expressions using Regex_Automata.
with Ada.Strings.Unbounded;
with Ada.Text_IO;

package Expr_Tokenizer is

   type Token_Kind is
     (Plus,
      Minus,
      Star,
      Slash,
      Percent,
      Caret,
      LParen,
      RParen,
      Number,
      Function_Name,
      Constant_Name,
      Variable);

   type Token is record
      Kind   : Token_Kind;
      Lexeme : Ada.Strings.Unbounded.Unbounded_String;
      Line   : Positive := 1;
      Column : Positive := 1;
   end record;

   type Token_Array is array (Positive range <>) of Token;

   type Token_Array_Access is access Token_Array;

   type Diagnostic is record
      Line    : Positive := 1;
      Column  : Positive := 1;
      Message : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   type Diagnostic_Array is array (Positive range <>) of Diagnostic;

   type Diagnostic_Array_Access is access Diagnostic_Array;

   type Tokenize_Result is record
      Tokens       : Token_Array_Access := null;
      Diagnostics  : Diagnostic_Array_Access := null;
      Had_Errors   : Boolean := False;
   end record;

   function Kind_Name (Kind : Token_Kind) return String;
   --  Stable uppercase dump name for Kind.

   function Tokenize (Source : String) return Tokenize_Result;
   --  Scan Source. Invalid tokens become diagnostics; scanning continues.
   --  Only valid tokens are returned in Tokens.

   procedure Write_Dump
     (Tokens : Token_Array;
      File   : Ada.Text_IO.File_Type);
   --  Write the canonical .tokens dump to an open file.

   procedure Write_Dump_To_Stdout (Tokens : Token_Array);
   --  Write the canonical .tokens dump to standard output.

end Expr_Tokenizer;
