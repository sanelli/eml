--  Invoke a native C compiler to build exe / static lib / shared lib.
with IR_Eml;

package C_Build is

   type Build_Result is record
      Ok           : Boolean;
      Error_Text   : String (1 .. 4096);
      Error_Length : Natural := 0;
   end record;

   function Host_Is_Windows return Boolean;
   --  True when OS=Windows_NT.

   function Host_Is_Darwin return Boolean;
   --  True when uname -s is Darwin.

   function Native_Exe_Expected_Suffix return String;
   --  ".exe" on Windows; "no extension (not .exe)" on Linux/macOS.

   function Native_Lib_Expected_Suffix return String;
   --  ".lib" on Windows; ".a" on Linux/macOS.

   function Native_Dynamiclib_Expected_Suffix return String;
   --  ".dll" on Windows; ".dylib" on macOS; ".so" on Linux.

   function Native_Exe_Path_Matches (Output_Path : String) return Boolean;

   function Native_Lib_Path_Matches (Output_Path : String) return Boolean;

   function Native_Dynamiclib_Path_Matches
     (Output_Path : String) return Boolean;

   function C_Compiler_On_Path return Boolean;
   --  True when clang, gcc, or (on Windows) cl can be located.

   function Selected_C_Compiler_Image return String;
   --  "clang", "gcc", or "cl"; empty when none on PATH.

   function Build_Native_Exe
     (Root          : IR_Eml.Node_Access;
      Meta          : IR_Eml.Dump_Meta;
      Output_Path   : String;
      Function_Name : String) return Build_Result;

   function Build_Native_Lib
     (Root          : IR_Eml.Node_Access;
      Meta          : IR_Eml.Dump_Meta;
      Output_Path   : String;
      Function_Name : String;
      Emit_Eml      : Boolean) return Build_Result;

   function Build_Native_Dynamiclib
     (Root          : IR_Eml.Node_Access;
      Meta          : IR_Eml.Dump_Meta;
      Output_Path   : String;
      Function_Name : String;
      Emit_Eml      : Boolean) return Build_Result;

end C_Build;
