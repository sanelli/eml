--  Textual $VARNAME substitution before .teml tokenization.
with Ada.Strings.Unbounded;

with Expr_Tokenizer;

package Expr_Preprocessor is

   package US renames Ada.Strings.Unbounded;

   type Binding is record
      Name  : US.Unbounded_String;
      Value : US.Unbounded_String;
   end record;

   type Binding_Array is array (Positive range <>) of Binding;

   type Unbound_Diagnostic is record
      Line     : Positive := 1;
      Column   : Positive := 1;
      Var_Name : US.Unbounded_String;
   end record;

   type Unbound_Array is array (Positive range <>) of Unbound_Diagnostic;

   type Unbound_Array_Access is access Unbound_Array;

   type Name_Array is array (Positive range <>) of US.Unbounded_String;

   type Name_Array_Access is access Name_Array;

   type Preprocess_Result is record
      Text      : US.Unbounded_String;
      Origins   : Expr_Tokenizer.Origin_Map_Access := null;
      Unbound   : Unbound_Array_Access := null;
      Unused    : Name_Array_Access := null;
      Had_Error : Boolean := False;
   end record;

   function Preprocess
     (Source   : String;
      Bindings : Binding_Array) return Preprocess_Result;
   --  Scan Source, substitute bound $VARNAME tokens, build per-character
   --  origin map. Unbound occurrences are collected; Had_Error is set when
   --  any exist. Unused lists binding names never matched in Source.

end Expr_Preprocessor;
