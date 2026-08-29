with Ada.Directories;
with Ada.Text_IO;
with C_Build;

package body C_Build_Tests is

   use C_Build;

   procedure Run (Failed : in out Boolean) is

      procedure Require (Cond : Boolean; Message : String) is
      begin
         if not Cond then
            Failed := True;
            Ada.Text_IO.Put_Line ("FAIL: " & Message);
         end if;
      end Require;

   begin
      if Host_Is_Windows then
         Require
           (Native_Exe_Expected_Suffix = ".exe",
            "cbuild: exe suffix windows");
         Require
           (Native_Lib_Expected_Suffix = ".lib",
            "cbuild: lib suffix windows");
         Require
           (Native_Dynamiclib_Expected_Suffix = ".dll",
            "cbuild: dyn suffix windows");
         Require
           (Native_Exe_Path_Matches ("out.exe"),
            "cbuild: exe match windows");
         Require
           (not Native_Exe_Path_Matches ("out"),
            "cbuild: exe no ext windows");
         Require
           (Native_Lib_Path_Matches ("out.lib"),
            "cbuild: lib match windows");
         Require
           (Native_Dynamiclib_Path_Matches ("out.dll"),
            "cbuild: dyn match windows");
      else
         Require
           (Native_Exe_Expected_Suffix = "no extension (not .exe)",
            "cbuild: exe suffix unix");
         Require
           (Native_Lib_Expected_Suffix = ".a",
            "cbuild: lib suffix unix");
         if Host_Is_Darwin then
            Require
              (Native_Dynamiclib_Expected_Suffix = ".dylib",
               "cbuild: dyn suffix darwin");
            Require
              (Native_Dynamiclib_Path_Matches ("out.dylib"),
               "cbuild: dyn match darwin");
         else
            Require
              (Native_Dynamiclib_Expected_Suffix = ".so",
               "cbuild: dyn suffix linux");
            Require
              (Native_Dynamiclib_Path_Matches ("out.so"),
               "cbuild: dyn match linux");
         end if;
         Require
           (Native_Exe_Path_Matches ("out"),
            "cbuild: exe match unix");
         Require
           (not Native_Exe_Path_Matches ("out.exe"),
            "cbuild: exe ext unix");
         Require
           (Native_Lib_Path_Matches ("out.a"),
            "cbuild: lib match unix");
         Require
           (Ada.Directories.Extension ("/tmp/out") = "",
            "cbuild: extension helper");
      end if;

      declare
         On_Path : constant Boolean := C_Compiler_On_Path;
         Image   : constant String := Selected_C_Compiler_Image;
      begin
         Require
           (On_Path = (Image'Length > 0),
            "cbuild: compiler on path vs image");
         if On_Path then
            Require
              (Image = "clang" or else Image = "gcc"
               or else (Host_Is_Windows and then Image = "cl"),
               "cbuild: compiler image known");
         end if;
      end;
   end Run;

end C_Build_Tests;
