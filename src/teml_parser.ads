--  Parse nested .teml tokens into IR_Eml.
with Ada.Strings.Unbounded;
with Eml.Diagnostics;
with IR_Eml;
with Teml_Tokenizer;

package Teml_Parser is

   type Parse_Result is record
      Root       : IR_Eml.Node_Access := null;
      Had_Error  : Boolean := False;
      Error_Id   : Eml.Diagnostics.Diagnostic_Id;
      Error_Line : Positive := 1;
      Error_Col  : Positive := 1;
      Param1     : Ada.Strings.Unbounded.Unbounded_String;
      From_Var   : Boolean := False;
      Var_Name   : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   function Parse (Tokens : Teml_Tokenizer.Token_Array) return Parse_Result;

end Teml_Parser;
