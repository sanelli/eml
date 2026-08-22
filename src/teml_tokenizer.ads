--  Tokenize nested .teml (1 and eml(S, S)) using Regex_Automata.
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Eml.Diagnostics;

package Teml_Tokenizer is

   type Token_Kind is (One, Eml_Kw, LParen, RParen, Comma);

   type Origin is record
      Line     : Positive := 1;
      Column   : Positive := 1;
      From_Var : Boolean := False;
      Var_Name : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   type Origin_Map is array (Positive range <>) of Origin;
   type Origin_Map_Access is access Origin_Map;

   type Token is record
      Kind     : Token_Kind;
      Lexeme   : Ada.Strings.Unbounded.Unbounded_String;
      Line     : Positive := 1;
      Column   : Positive := 1;
      From_Var : Boolean := False;
      Var_Name : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   type Token_Array is array (Positive range <>) of Token;
   type Token_Array_Access is access Token_Array;

   type Diagnostic is record
      Id       : Eml.Diagnostics.Diagnostic_Id;
      Line     : Positive := 1;
      Column   : Positive := 1;
      Param1   : Ada.Strings.Unbounded.Unbounded_String;
      From_Var : Boolean := False;
      Var_Name : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   type Diagnostic_Array is array (Positive range <>) of Diagnostic;
   type Diagnostic_Array_Access is access Diagnostic_Array;

   type Tokenize_Result is record
      Tokens      : Token_Array_Access := null;
      Diagnostics : Diagnostic_Array_Access := null;
      Had_Errors  : Boolean := False;
   end record;

   function Kind_Name (Kind : Token_Kind) return String;

   function Tokenize (Source : String) return Tokenize_Result;

   function Tokenize
     (Source  : String;
      Origins : Origin_Map_Access) return Tokenize_Result;

   procedure Write_Dump
     (Tokens : Token_Array;
      File   : Ada.Text_IO.File_Type);

   procedure Write_Dump_To_Stdout (Tokens : Token_Array);

end Teml_Tokenizer;
