--  Compile IR EML to IL (MSIL) text for ilasm.
with IR_Eml;

package Il_Backend is

   Default_Function_Name : constant String := "Compute";
   Default_Framework     : constant String := "net8.0";

   function Format_Il_Program
     (Root            : IR_Eml.Node_Access;
      Meta            : IR_Eml.Dump_Meta;
      Function_Name   : String := Default_Function_Name;
      Target_Framework : String := Default_Framework) return String;

   function Format_Il_Lib
     (Root            : IR_Eml.Node_Access;
      Meta            : IR_Eml.Dump_Meta;
      Function_Name   : String := Default_Function_Name;
      Target_Framework : String := Default_Framework) return String;

   procedure Write_Il_Program_To_File
     (Root             : IR_Eml.Node_Access;
      Meta             : IR_Eml.Dump_Meta;
      Path             : String;
      Function_Name    : String := Default_Function_Name;
      Target_Framework : String := Default_Framework);

   procedure Write_Il_Program_To_Stdout
     (Root             : IR_Eml.Node_Access;
      Meta             : IR_Eml.Dump_Meta;
      Function_Name    : String := Default_Function_Name;
      Target_Framework : String := Default_Framework);

   procedure Write_Il_Lib_To_File
     (Root             : IR_Eml.Node_Access;
      Meta             : IR_Eml.Dump_Meta;
      Path             : String;
      Function_Name    : String := Default_Function_Name;
      Target_Framework : String := Default_Framework);

   procedure Write_Il_Lib_To_Stdout
     (Root             : IR_Eml.Node_Access;
      Meta             : IR_Eml.Dump_Meta;
      Function_Name    : String := Default_Function_Name;
      Target_Framework : String := Default_Framework);

end Il_Backend;
