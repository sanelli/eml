--  Compile IR EML to C# source and SDK-style .csproj companions.
with IR_Eml;

package Dotnet_Backend is

   Default_Function_Name : constant String := "Compute";
   Default_Framework     : constant String := "net8.0";

   function Format_CSharp_Program
     (Root          : IR_Eml.Node_Access;
      Meta          : IR_Eml.Dump_Meta;
      Function_Name : String := Default_Function_Name) return String;
   --  Standalone .cs with static class Eml: eml, Compute, Main.

   function Format_CSharp_Lib
     (Root          : IR_Eml.Node_Access;
      Meta          : IR_Eml.Dump_Meta;
      Function_Name : String := Default_Function_Name) return String;
   --  Library .cs with eml and Compute; no Main.

   function Format_Csproj
     (Source_File_Name : String;
      Target_Framework : String := Default_Framework;
      Is_Executable    : Boolean := True) return String;

   function Companion_Csproj_Path (Cs_Path : String) return String;
   --  Same directory and basename as Cs_Path, with .csproj extension.

   procedure Write_CSharp_Program_To_File
     (Root                 : IR_Eml.Node_Access;
      Meta                 : IR_Eml.Dump_Meta;
      Path                 : String;
      Function_Name        : String := Default_Function_Name;
      Target_Framework     : String := Default_Framework;
      Write_Companion_Proj : Boolean := True);

   procedure Write_CSharp_Program_To_Stdout
     (Root          : IR_Eml.Node_Access;
      Meta          : IR_Eml.Dump_Meta;
      Function_Name : String := Default_Function_Name);

   procedure Write_CSharp_Lib_To_File
     (Root                 : IR_Eml.Node_Access;
      Meta                 : IR_Eml.Dump_Meta;
      Path                 : String;
      Function_Name        : String := Default_Function_Name;
      Target_Framework     : String := Default_Framework;
      Write_Companion_Proj : Boolean := True);

   procedure Write_CSharp_Lib_To_Stdout
     (Root          : IR_Eml.Node_Access;
      Meta          : IR_Eml.Dump_Meta;
      Function_Name : String := Default_Function_Name);

end Dotnet_Backend;
