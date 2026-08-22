--  Reconstruct IR_Eml from BEML opcodes.
with Eml.Diagnostics;
with IR_Eml;

package Beml_Parser is

   type Parse_Result is record
      Root       : IR_Eml.Node_Access := null;
      Had_Error  : Boolean := False;
      Error_Id   : Eml.Diagnostics.Diagnostic_Id;
      Error_Line : Positive := 1;
      Error_Col  : Positive := 1;
   end record;

   function Parse (Ops : IR_Eml.Opcode_Array) return Parse_Result;

   function Parse (Ops : IR_Eml.Opcode_Array_Access) return Parse_Result;

end Beml_Parser;
