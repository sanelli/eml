--  Invoke the dotnet SDK to build or publish generated C# projects.
with IR_Eml;

package Dotnet_Build is

   type Build_Result is record
      Ok           : Boolean;
      Error_Text   : String (1 .. 4096);
      Error_Length : Natural := 0;
   end record;

   function Host_Is_Windows return Boolean;
   --  True when this eml binary was built for Windows.

   function Host_Runtime_Id return String;
   --  dotnet RID for this host (osx-arm64, linux-x64, win-x64, ...).
   --  Empty when the host OS/arch is not a supported publish target.

   function Csharp_Exe_Expected_Suffix return String;
   --  ".exe" on Windows; "no extension (not .exe)" on Linux/macOS.

   function Csharp_Exe_Path_Matches (Output_Path : String) return Boolean;
   --  Windows: path ends in .exe. Linux/macOS: path has no extension.

   function Dotnet_On_Path return Boolean;
   --  True when the dotnet executable can be located.

   function Build_Csharp_Dll
     (Root             : IR_Eml.Node_Access;
      Meta             : IR_Eml.Dump_Meta;
      Output_Dll_Path  : String;
      Function_Name    : String;
      Target_Framework : String) return Build_Result;
   --  Program sources, `dotnet build -c Release`, copy Program.dll.

   function Build_Csharp_Lib_Dll
     (Root             : IR_Eml.Node_Access;
      Meta             : IR_Eml.Dump_Meta;
      Output_Dll_Path  : String;
      Function_Name    : String;
      Target_Framework : String) return Build_Result;
   --  Library sources, `dotnet build -c Release`, copy Program.dll.

   function Publish_Csharp_Exe
     (Root             : IR_Eml.Node_Access;
      Meta             : IR_Eml.Dump_Meta;
      Output_Exe_Path  : String;
      Function_Name    : String;
      Target_Framework : String) return Build_Result;
   --  Program sources, `dotnet publish` single-file, copy apphost.

end Dotnet_Build;
