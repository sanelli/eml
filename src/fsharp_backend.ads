--  Compile IR EML to F# source and SDK-style .fsproj companions.
with IR_Eml;

package Fsharp_Backend is

   Default_Function_Name : constant String := "Compute";
   Default_Framework     : constant String := "net8.0";

   function Format_FSharp_Program
     (Root          : IR_Eml.Node_Access;
      Meta          : IR_Eml.Dump_Meta;
      Function_Name : String := Default_Function_Name) return String;

   function Format_FSharp_Lib
     (Root          : IR_Eml.Node_Access;
      Meta          : IR_Eml.Dump_Meta;
      Function_Name : String := Default_Function_Name) return String;

   function Format_Fsproj
     (Source_File_Name : String;
      Target_Framework : String := Default_Framework;
      Is_Executable    : Boolean := True) return String;

   function Companion_Fsproj_Path (Fs_Path : String) return String;

   procedure Write_FSharp_Program_To_File
     (Root                 : IR_Eml.Node_Access;
      Meta                 : IR_Eml.Dump_Meta;
      Path                 : String;
      Function_Name        : String := Default_Function_Name;
      Target_Framework     : String := Default_Framework;
      Write_Companion_Proj : Boolean := True);

   procedure Write_FSharp_Program_To_Stdout
     (Root          : IR_Eml.Node_Access;
      Meta          : IR_Eml.Dump_Meta;
      Function_Name : String := Default_Function_Name);

   procedure Write_FSharp_Lib_To_File
     (Root                 : IR_Eml.Node_Access;
      Meta                 : IR_Eml.Dump_Meta;
      Path                 : String;
      Function_Name        : String := Default_Function_Name;
      Target_Framework     : String := Default_Framework;
      Write_Companion_Proj : Boolean := True);

   procedure Write_FSharp_Lib_To_Stdout
     (Root          : IR_Eml.Node_Access;
      Meta          : IR_Eml.Dump_Meta;
      Function_Name : String := Default_Function_Name);

end Fsharp_Backend;
