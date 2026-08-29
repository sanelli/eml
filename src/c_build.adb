with Ada.Characters.Handling;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Text_IO;
with GNAT.OS_Lib;

with C_Backend;

package body C_Build is

   use C_Backend;
   use GNAT.OS_Lib;
   use IR_Eml;

   type Compiler_Kind is (Clang, Gcc, Cl);

   Temp_Counter    : Natural := 0;
   Darwin_Cache    : Boolean := False;
   Darwin_Ready    : Boolean := False;
   Selected_Kind   : Compiler_Kind;
   Selected_Path   : GNAT.OS_Lib.String_Access := null;
   Selected_Ready  : Boolean := False;

   function Temp_Root return String;
   procedure Free_Args (Args : in out Argument_List);

   function Host_Is_Windows return Boolean is
      OS : constant GNAT.OS_Lib.String_Access := Getenv ("OS");
   begin
      return OS /= null and then OS.all = "Windows_NT";
   end Host_Is_Windows;

   function Strip_Newline (S : String) return String is
      Last : Natural := S'Last;
   begin
      while Last >= S'First
        and then (S (Last) = ASCII.LF or else S (Last) = ASCII.CR)
      loop
         Last := Last - 1;
      end loop;
      if Last < S'First then
         return "";
      end if;
      return S (S'First .. Last);
   end Strip_Newline;

   function Read_Small_File (Path : String) return String is
      File : Ada.Text_IO.File_Type;
      Line : String (1 .. 64);
      Last : Natural;
   begin
      if not Ada.Directories.Exists (Path) then
         return "";
      end if;
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      if Ada.Text_IO.End_Of_File (File) then
         Ada.Text_IO.Close (File);
         return "";
      end if;
      Ada.Text_IO.Get_Line (File, Line, Last);
      Ada.Text_IO.Close (File);
      return Strip_Newline (Line (1 .. Last));
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         return "";
   end Read_Small_File;

   function Capture_Uname (Flag : String) return String is
      Uname : GNAT.OS_Lib.String_Access :=
        Locate_Exec_On_Path ("uname");
      Out_P : constant String :=
        Ada.Directories.Compose (Temp_Root, "eml_uname.txt");
      Args  : Argument_List (1 .. 1);
      Ok    : Boolean;
      Code  : Integer;
   begin
      if Uname = null then
         return "";
      end if;
      Args := Argument_List'(1 => new String'(Flag));
      Spawn (Uname.all, Args, Out_P, Ok, Code);
      Free_Args (Args);
      Free (Uname);
      if not Ok or else Code /= 0 then
         return "";
      end if;
      declare
         Text : constant String := Read_Small_File (Out_P);
      begin
         if Ada.Directories.Exists (Out_P) then
            Ada.Directories.Delete_File (Out_P);
         end if;
         return Text;
      end;
   end Capture_Uname;

   function Compute_Host_Is_Darwin return Boolean is
      Sys : constant String :=
        Ada.Characters.Handling.To_Lower (Capture_Uname ("-s"));
   begin
      return Sys = "darwin";
   end Compute_Host_Is_Darwin;

   function Host_Is_Darwin return Boolean is
   begin
      if Host_Is_Windows then
         return False;
      end if;
      if Darwin_Ready then
         return Darwin_Cache;
      end if;
      Darwin_Cache := Compute_Host_Is_Darwin;
      Darwin_Ready := True;
      return Darwin_Cache;
   end Host_Is_Darwin;

   function Ends_With_Ignore_Case (S, Suffix : String) return Boolean is
      use Ada.Characters.Handling;
   begin
      if S'Length < Suffix'Length then
         return False;
      end if;
      return To_Lower (S (S'Last - Suffix'Length + 1 .. S'Last))
        = To_Lower (Suffix);
   end Ends_With_Ignore_Case;

   function Native_Exe_Expected_Suffix return String is
   begin
      if Host_Is_Windows then
         return ".exe";
      end if;
      return "no extension (not .exe)";
   end Native_Exe_Expected_Suffix;

   function Native_Lib_Expected_Suffix return String is
   begin
      if Host_Is_Windows then
         return ".lib";
      end if;
      return ".a";
   end Native_Lib_Expected_Suffix;

   function Native_Dynamiclib_Expected_Suffix return String is
   begin
      if Host_Is_Windows then
         return ".dll";
      elsif Host_Is_Darwin then
         return ".dylib";
      end if;
      return ".so";
   end Native_Dynamiclib_Expected_Suffix;

   function Native_Exe_Path_Matches (Output_Path : String) return Boolean is
   begin
      if Host_Is_Windows then
         return Ends_With_Ignore_Case (Output_Path, ".exe");
      end if;
      return Ada.Directories.Extension (Output_Path) = "";
   end Native_Exe_Path_Matches;

   function Native_Lib_Path_Matches (Output_Path : String) return Boolean is
   begin
      if Host_Is_Windows then
         return Ends_With_Ignore_Case (Output_Path, ".lib");
      end if;
      return Ends_With_Ignore_Case (Output_Path, ".a");
   end Native_Lib_Path_Matches;

   function Native_Dynamiclib_Path_Matches
     (Output_Path : String) return Boolean
   is
      Suffix : constant String := Native_Dynamiclib_Expected_Suffix;
   begin
      return Ends_With_Ignore_Case (Output_Path, Suffix);
   end Native_Dynamiclib_Path_Matches;

   procedure Ensure_Selected_Compiler is
      Clang_P : GNAT.OS_Lib.String_Access;
      Gcc_P   : GNAT.OS_Lib.String_Access;
      Cl_P    : GNAT.OS_Lib.String_Access;
   begin
      if Selected_Ready then
         return;
      end if;
      Clang_P := Locate_Exec_On_Path ("clang");
      if Clang_P /= null then
         Selected_Kind := Clang;
         Selected_Path := Clang_P;
         Selected_Ready := True;
         return;
      end if;
      Gcc_P := Locate_Exec_On_Path ("gcc");
      if Gcc_P /= null then
         Selected_Kind := Gcc;
         Selected_Path := Gcc_P;
         Selected_Ready := True;
         return;
      end if;
      if Host_Is_Windows then
         Cl_P := Locate_Exec_On_Path ("cl");
         if Cl_P /= null then
            Selected_Kind := Cl;
            Selected_Path := Cl_P;
            Selected_Ready := True;
            return;
         end if;
      end if;
      Selected_Ready := True;
   end Ensure_Selected_Compiler;

   function C_Compiler_On_Path return Boolean is
   begin
      Ensure_Selected_Compiler;
      return Selected_Path /= null;
   end C_Compiler_On_Path;

   function Selected_C_Compiler_Image return String is
   begin
      Ensure_Selected_Compiler;
      if Selected_Path = null then
         return "";
      end if;
      case Selected_Kind is
         when Clang => return "clang";
         when Gcc   => return "gcc";
         when Cl    => return "cl";
      end case;
   end Selected_C_Compiler_Image;

   function Temp_Root return String is
      Tmpdir : constant GNAT.OS_Lib.String_Access := Getenv ("TMPDIR");
      Temp   : constant GNAT.OS_Lib.String_Access := Getenv ("TEMP");
      Tmp    : constant GNAT.OS_Lib.String_Access := Getenv ("TMP");
   begin
      if Tmpdir /= null and then Tmpdir.all'Length > 0 then
         return Tmpdir.all;
      elsif Temp /= null and then Temp.all'Length > 0 then
         return Temp.all;
      elsif Tmp /= null and then Tmp.all'Length > 0 then
         return Tmp.all;
      else
         return "/tmp";
      end if;
   end Temp_Root;

   function Make_Temp_Dir return String is
      Base : constant String := Temp_Root;
      N    : Natural := Temp_Counter + 1;
   begin
      loop
         declare
            Img  : constant String := Natural'Image (N);
            Path : constant String :=
              Ada.Directories.Compose
                (Base, "eml_cc_" & Img (Img'First + 1 .. Img'Last));
         begin
            if not Ada.Directories.Exists (Path) then
               Temp_Counter := N;
               return Path;
            end if;
            N := N + 1;
         end;
      end loop;
   end Make_Temp_Dir;

   procedure Set_Error
     (Result : out Build_Result; Msg : String)
   is
      Len : constant Natural :=
        Natural'Min (Msg'Length, Result.Error_Text'Length);
   begin
      Result.Ok := False;
      Result.Error_Length := Len;
      if Len > 0 then
         Result.Error_Text (1 .. Len) :=
           Msg (Msg'First .. Msg'First + Len - 1);
      end if;
   end Set_Error;

   procedure Free_Args (Args : in out Argument_List) is
   begin
      for I in Args'Range loop
         if Args (I) /= null then
            declare
               Item : GNAT.OS_Lib.String_Access := Args (I);
            begin
               Args (I) := null;
               Free (Item);
            end;
         end if;
      end loop;
   end Free_Args;

   function Os_Exit_Code (Status : Integer) return Integer is
   begin
      if Status <= 0 then
         return Status;
      elsif Status > 255 then
         return (Status / 256) mod 256;
      else
         return Status;
      end if;
   end Os_Exit_Code;

   function Run_In_Dir
     (Work_Dir : String; Exe : String; Args : in out Argument_List)
      return Integer
   is
      Old : constant String := Ada.Directories.Current_Directory;
      Code : Integer;
   begin
      Ada.Directories.Set_Directory (Work_Dir);
      Code := Spawn (Exe, Args);
      Ada.Directories.Set_Directory (Old);
      Free_Args (Args);
      return Os_Exit_Code (Code);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old);
         Free_Args (Args);
         raise;
   end Run_In_Dir;

   procedure Write_Text_File (Path, Text : String) is
      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put (File, Text);
      Ada.Text_IO.Close (File);
   end Write_Text_File;

   procedure Make_Executable (Path : String) is
      Chmod : GNAT.OS_Lib.String_Access;
      Args  : Argument_List (1 .. 2);
   begin
      if Host_Is_Windows then
         return;
      end if;
      Chmod := Locate_Exec_On_Path ("chmod");
      if Chmod = null then
         return;
      end if;
      Args :=
        Argument_List'
          (1 => new String'("+x"),
           2 => new String'(Path));
      declare
         Unused : constant Integer := Spawn (Chmod.all, Args);
         pragma Unreferenced (Unused);
      begin
         Free_Args (Args);
         Free (Chmod);
      end;
   end Make_Executable;

   function Output_Companion_Header_Path
     (Output_Path : String) return String
   is
      Dir    : constant String :=
        Ada.Directories.Containing_Directory (Output_Path);
      Simple : constant String := Ada.Directories.Simple_Name (Output_Path);
      Ext    : constant String := Ada.Directories.Extension (Output_Path);
      Base   : String (1 .. Simple'Length);
      Base_Len : Natural;
   begin
      if Ext'Length = 0 then
         return Ada.Directories.Compose (Dir, Simple & ".h");
      end if;
      Base_Len := Simple'Length - Ext'Length - 1;
      Base (1 .. Base_Len) :=
        Simple (Simple'First .. Simple'First + Base_Len - 1);
      return Ada.Directories.Compose (Dir, Base (1 .. Base_Len) & ".h");
   end Output_Companion_Header_Path;

   function Temp_Artifact_Name
     (Kind : Compiler_Kind; Job : String) return String
   is
      pragma Unreferenced (Kind);
   begin
      if Job = "exe" then
         if Host_Is_Windows then
            return "eml_out.exe";
         end if;
         return "eml_out";
      elsif Job = "lib" then
         if Host_Is_Windows then
            return "eml_out.lib";
         end if;
         return "eml_out.a";
      else
         return "eml_out" & Native_Dynamiclib_Expected_Suffix;
      end if;
   end Temp_Artifact_Name;

   function Find_Archiver return GNAT.OS_Lib.String_Access is
      Llvm : GNAT.OS_Lib.String_Access;
      Ar   : GNAT.OS_Lib.String_Access;
   begin
      Ensure_Selected_Compiler;
      if Selected_Kind = Clang then
         Llvm := Locate_Exec_On_Path ("llvm-ar");
         if Llvm /= null then
            return Llvm;
         end if;
      end if;
      Ar := Locate_Exec_On_Path ("ar");
      return Ar;
   end Find_Archiver;

   function Compile_Exe
     (Work_Dir : String; Artifact : String) return Integer
   is
      C_Path : constant String := "eml.c";
   begin
      Ensure_Selected_Compiler;
      case Selected_Kind is
         when Clang | Gcc =>
            declare
               Args : Argument_List :=
                 (if Host_Is_Windows then
                    Argument_List'
                      (1 => new String'("-std=c11"),
                       2 => new String'("-O2"),
                       3 => new String'("-o"),
                       4 => new String'(Artifact),
                       5 => new String'(C_Path))
                  else
                    Argument_List'
                      (1 => new String'("-std=c11"),
                       2 => new String'("-O2"),
                       3 => new String'("-o"),
                       4 => new String'(Artifact),
                       5 => new String'(C_Path),
                       6 => new String'("-lm")));
            begin
               return Run_In_Dir (Work_Dir, Selected_Path.all, Args);
            end;
         when Cl =>
            declare
               Fe : constant String := "/Fe:" & Artifact;
               Args : Argument_List :=
                 Argument_List'
                   (1 => new String'("/nologo"),
                    2 => new String'("/O2"),
                    3 => new String'("/std:c11"),
                    4 => new String'(Fe),
                    5 => new String'(C_Path));
            begin
               return Run_In_Dir (Work_Dir, Selected_Path.all, Args);
            end;
      end case;
   end Compile_Exe;

   function Compile_Static_Lib
     (Work_Dir : String; Artifact : String) return Integer
   is
      C_Path : constant String := "eml.c";
      Obj    : constant String :=
        (if Selected_Kind = Cl then "eml.obj" else "eml.o");
   begin
      Ensure_Selected_Compiler;
      case Selected_Kind is
         when Clang | Gcc =>
            declare
               Compile_Args : Argument_List :=
                 Argument_List'
                   (1 => new String'("-std=c11"),
                    2 => new String'("-O2"),
                    3 => new String'("-c"),
                    4 => new String'("-o"),
                    5 => new String'(Obj),
                    6 => new String'(C_Path));
               Exit_Code : Integer := Run_In_Dir
                 (Work_Dir, Selected_Path.all, Compile_Args);
               Archiver  : GNAT.OS_Lib.String_Access := Find_Archiver;
               Arc_Args  : Argument_List (1 .. 3);
            begin
               if Exit_Code /= 0 then
                  if Archiver /= null then
                     Free (Archiver);
                  end if;
                  return Exit_Code;
               end if;
               if Archiver = null then
                  return 127;
               end if;
               Arc_Args :=
                 Argument_List'
                   (1 => new String'("rcs"),
                    2 => new String'(Artifact),
                    3 => new String'(Obj));
               Exit_Code := Run_In_Dir (Work_Dir, Archiver.all, Arc_Args);
               Free (Archiver);
               return Exit_Code;
            end;
         when Cl =>
            declare
               Compile_Args : Argument_List :=
                 Argument_List'
                   (1 => new String'("/nologo"),
                    2 => new String'("/O2"),
                    3 => new String'("/std:c11"),
                    4 => new String'("/c"),
                    5 => new String'(C_Path));
               Exit_Code : Integer := Run_In_Dir
                 (Work_Dir, Selected_Path.all, Compile_Args);
               Lib_Tool  : GNAT.OS_Lib.String_Access :=
                 Locate_Exec_On_Path ("lib");
               Out_Arg   : constant String := "/out:" & Artifact;
               Lib_Args  : Argument_List (1 .. 3);
            begin
               if Exit_Code /= 0 then
                  if Lib_Tool /= null then
                     Free (Lib_Tool);
                  end if;
                  return Exit_Code;
               end if;
               if Lib_Tool = null then
                  return 127;
               end if;
               Lib_Args :=
                 Argument_List'
                   (1 => new String'("/nologo"),
                    2 => new String'(Out_Arg),
                    3 => new String'(Obj));
               Exit_Code := Run_In_Dir (Work_Dir, Lib_Tool.all, Lib_Args);
               Free (Lib_Tool);
               return Exit_Code;
            end;
      end case;
   end Compile_Static_Lib;

   function Compile_Shared_Lib
     (Work_Dir : String; Artifact : String) return Integer
   is
      C_Path : constant String := "eml.c";
   begin
      Ensure_Selected_Compiler;
      case Selected_Kind is
         when Clang | Gcc =>
            declare
               Args : Argument_List :=
                 (if Host_Is_Windows then
                    Argument_List'
                      (1 => new String'("-std=c11"),
                       2 => new String'("-O2"),
                       3 => new String'("-shared"),
                       4 => new String'("-o"),
                       5 => new String'(Artifact),
                       6 => new String'(C_Path))
                  elsif Host_Is_Darwin then
                    Argument_List'
                      (1 => new String'("-std=c11"),
                       2 => new String'("-O2"),
                       3 => new String'("-dynamiclib"),
                       4 => new String'("-o"),
                       5 => new String'(Artifact),
                       6 => new String'(C_Path),
                       7 => new String'("-lm"))
                  else
                    Argument_List'
                      (1 => new String'("-std=c11"),
                       2 => new String'("-O2"),
                       3 => new String'("-shared"),
                       4 => new String'("-fPIC"),
                       5 => new String'("-o"),
                       6 => new String'(Artifact),
                       7 => new String'(C_Path),
                       8 => new String'("-lm")));
            begin
               return Run_In_Dir (Work_Dir, Selected_Path.all, Args);
            end;
         when Cl =>
            declare
               Fe : constant String := "/Fe:" & Artifact;
               Args : Argument_List :=
                 Argument_List'
                   (1 => new String'("/nologo"),
                    2 => new String'("/O2"),
                    3 => new String'("/std:c11"),
                    4 => new String'("/LD"),
                    5 => new String'(Fe),
                    6 => new String'(C_Path));
            begin
               return Run_In_Dir (Work_Dir, Selected_Path.all, Args);
            end;
      end case;
   end Compile_Shared_Lib;

   type Job_Kind is (Build_Exe, Build_Lib, Build_Dynamiclib);

   function Run_Job
     (Root          : IR_Eml.Node_Access;
      Meta          : IR_Eml.Dump_Meta;
      Function_Name : String;
      Emit_Eml      : Boolean;
      Dll_Export    : Boolean;
      Kind          : Job_Kind;
      Output_Path   : String) return Build_Result
   is
      Result    : Build_Result;
      Temp_Dir  : constant String := Make_Temp_Dir;
      C_Path    : constant String :=
        Ada.Directories.Compose (Temp_Dir, "eml.c");
      H_Path    : constant String :=
        Ada.Directories.Compose (Temp_Dir, "eml.h");
      Artifact  : constant String :=
        Temp_Artifact_Name (Selected_Kind, (case Kind is
            when Build_Exe => "exe",
            when Build_Lib => "lib",
            when Build_Dynamiclib => "dynamiclib"));
      Built     : constant String :=
        Ada.Directories.Compose (Temp_Dir, Artifact);
      Exit_Code : Integer;
      Job_Label : constant String :=
        (case Kind is
            when Build_Exe => "exe",
            when Build_Lib => "lib",
            when Build_Dynamiclib => "dynamiclib");
   begin
      Result.Ok := False;
      Result.Error_Length := 0;
      Ensure_Selected_Compiler;
      if Selected_Path = null then
         Set_Error (Result, "no C compiler on PATH");
         return Result;
      end if;

      begin
         Ada.Directories.Create_Directory (Temp_Dir);

         case Kind is
            when Build_Exe =>
               Write_Text_File
                 (C_Path,
                  Format_C_Exe_Program (Root, Meta, Function_Name));
            when Build_Lib | Build_Dynamiclib =>
               Write_Text_File
                 (C_Path,
                  Format_C_Lib
                    (Root, Meta, "eml.h", Function_Name, Emit_Eml,
                     Dll_Export));
               Write_Text_File
                 (H_Path,
                  Format_C_Header
                    ("EML_H", Function_Name, Emit_Eml, Dll_Export));
         end case;

         case Kind is
            when Build_Exe =>
               Exit_Code := Compile_Exe (Temp_Dir, Artifact);
            when Build_Lib =>
               Exit_Code := Compile_Static_Lib (Temp_Dir, Artifact);
            when Build_Dynamiclib =>
               Exit_Code := Compile_Shared_Lib (Temp_Dir, Artifact);
         end case;

         if Exit_Code /= 0 then
            Set_Error
              (Result,
               "C compile (" & Job_Label & ") failed with exit code "
               & Integer'Image (Exit_Code));
            Ada.Directories.Delete_Tree (Temp_Dir);
            return Result;
         end if;

         if not Ada.Directories.Exists (Built) then
            Set_Error
              (Result,
               "C compile (" & Job_Label & ") produced no output file");
            Ada.Directories.Delete_Tree (Temp_Dir);
            return Result;
         end if;

         Ada.Directories.Copy_File (Built, Output_Path);

         if Kind = Build_Exe then
            Make_Executable (Output_Path);
         else
            declare
               Out_H : constant String :=
                 Output_Companion_Header_Path (Output_Path);
               Guard : constant String :=
                 Header_Guard
                   (Ada.Directories.Base_Name (Output_Path));
            begin
               Write_Text_File
                 (Out_H,
                  Format_C_Header
                    (Guard, Function_Name, Emit_Eml, Dll_Export));
            end;
         end if;

         Ada.Directories.Delete_Tree (Temp_Dir);
         Result.Ok := True;
         return Result;

      exception
         when E : others =>
            if Ada.Directories.Exists (Temp_Dir) then
               Ada.Directories.Delete_Tree (Temp_Dir);
            end if;
            Set_Error (Result, Ada.Exceptions.Exception_Message (E));
            return Result;
      end;
   end Run_Job;

   function Build_Native_Exe
     (Root          : IR_Eml.Node_Access;
      Meta          : IR_Eml.Dump_Meta;
      Output_Path   : String;
      Function_Name : String) return Build_Result
   is
   begin
      return Run_Job
        (Root, Meta, Function_Name, False, False, Build_Exe, Output_Path);
   end Build_Native_Exe;

   function Build_Native_Lib
     (Root          : IR_Eml.Node_Access;
      Meta          : IR_Eml.Dump_Meta;
      Output_Path   : String;
      Function_Name : String;
      Emit_Eml      : Boolean) return Build_Result
   is
   begin
      return Run_Job
        (Root, Meta, Function_Name, Emit_Eml, False, Build_Lib, Output_Path);
   end Build_Native_Lib;

   function Build_Native_Dynamiclib
     (Root          : IR_Eml.Node_Access;
      Meta          : IR_Eml.Dump_Meta;
      Output_Path   : String;
      Function_Name : String;
      Emit_Eml      : Boolean) return Build_Result
   is
   begin
      return Run_Job
        (Root, Meta, Function_Name, Emit_Eml, True, Build_Dynamiclib,
         Output_Path);
   end Build_Native_Dynamiclib;

end C_Build;
