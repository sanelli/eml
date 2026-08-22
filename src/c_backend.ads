--  Compile IR EML to C (standalone program or library + header).
with IR_Eml;

package C_Backend is

   function Format_C_Program
     (Root : IR_Eml.Node_Access; Meta : IR_Eml.Dump_Meta) return String;
   --  Standalone .c with static eml and main that prints the result.

   function Format_C_Lib
     (Root               : IR_Eml.Node_Access;
      Meta               : IR_Eml.Dump_Meta;
      Header_Include_Name : String) return String;
   --  Library .c with #include "Header_Include_Name", eml, and compute.

   function Format_C_Header (Guard_Name : String) return String;
   --  Companion .h with eml and compute declarations.

   function Companion_Header_Path (C_Path : String) return String;
   --  Same directory and basename as C_Path, with .h extension.

   function Header_Guard (Base_Name : String) return String;
   --  Include guard from basename: non-alnum -> '_', uppercased, + "_H".

   procedure Write_C_Program_To_File
     (Root : IR_Eml.Node_Access; Meta : IR_Eml.Dump_Meta; Path : String);

   procedure Write_C_Program_To_Stdout
     (Root : IR_Eml.Node_Access; Meta : IR_Eml.Dump_Meta);

   procedure Write_C_Lib_To_File
     (Root : IR_Eml.Node_Access; Meta : IR_Eml.Dump_Meta; Path : String);
   --  Writes .c and companion .h beside Path.

   procedure Write_C_Lib_To_Stdout
     (Root : IR_Eml.Node_Access; Meta : IR_Eml.Dump_Meta);
   --  Library .c only (include name "eml_generated.h"); no header file.

end C_Backend;
