--  Read .beml binary into opcode stream.
with Ada.Streams;
with Eml.Diagnostics;
with IR_Eml;

package Beml_Reader is

   type Read_Result is record
      Opcodes    : IR_Eml.Opcode_Array_Access := null;
      Had_Error  : Boolean := False;
      Error_Id   : Eml.Diagnostics.Diagnostic_Id;
      Error_Line : Positive := 1;
      Error_Col  : Positive := 1;
   end record;

   function Read_Bytes (Data : Ada.Streams.Stream_Element_Array)
      return Read_Result;

   function Read_File (Path : String) return Read_Result;

end Beml_Reader;
