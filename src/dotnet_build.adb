with Ada.Characters.Handling;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Text_IO;
with GNAT.OS_Lib;

with Dotnet_Backend;

package body Dotnet_Build is

   use Dotnet_Backend;
   use GNAT.OS_Lib;
   use IR_Eml;

   Temp_Counter : Natural := 0;
   Rid_Cache    : String (1 .. 32) := [others => ' '];
   Rid_Length   : Natural := 0;
   Rid_Ready    : Boolean := False;

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
      Uname : constant GNAT.OS_Lib.String_Access :=
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

   function Arch_Rid_Suffix (Arch : String) return String is
      A : constant String := Ada.Characters.Handling.To_Lower (Arch);
   begin
      if A = "aarch64" or else A = "arm64" then
         return "arm64";
      elsif A = "x86_64" or else A = "amd64" then
         return "x64";
      elsif A = "i686" or else A = "i386" or else A = "x86" then
         return "x86";
      end if;
      return "";
   end Arch_Rid_Suffix;

   function Compute_Host_Runtime_Id return String is
      use Ada.Characters.Handling;
   begin
      if Host_Is_Windows then
         declare
            Arch_Env : constant GNAT.OS_Lib.String_Access :=
              Getenv ("PROCESSOR_ARCHITECTURE");
            Suffix   : constant String :=
              (if Arch_Env = null then ""
               else Arch_Rid_Suffix (Arch_Env.all));
         begin
            if Suffix = "" then
               return "";
            end if;
            return "win-" & Suffix;
         end;
      end if;

      declare
         Sys  : constant String := To_Lower (Capture_Uname ("-s"));
         Arch : constant String := Capture_Uname ("-m");
         Suf  : constant String := Arch_Rid_Suffix (Arch);
      begin
         if Suf = "" then
            return "";
         elsif Sys = "darwin" then
            return "osx-" & Suf;
         elsif Sys = "linux" then
            return "linux-" & Suf;
         end if;
         return "";
      end;
   end Compute_Host_Runtime_Id;

   function Host_Runtime_Id return String is
   begin
      if Rid_Ready then
         return Rid_Cache (1 .. Rid_Length);
      end if;
      declare
         Computed : constant String := Compute_Host_Runtime_Id;
      begin
         Rid_Length := Natural'Min (Computed'Length, Rid_Cache'Length);
         if Rid_Length > 0 then
            Rid_Cache (1 .. Rid_Length) :=
              Computed
                (Computed'First .. Computed'First + Rid_Length - 1);
         end if;
         Rid_Ready := True;
         return Rid_Cache (1 .. Rid_Length);
      end;
   end Host_Runtime_Id;

   function Csharp_Exe_Expected_Suffix return String is
   begin
      if Host_Is_Windows then
         return ".exe";
      end if;
      return "no extension (not .exe)";
   end Csharp_Exe_Expected_Suffix;

   function Ends_With_Ignore_Case (S, Suffix : String) return Boolean is
      use Ada.Characters.Handling;
   begin
      if S'Length < Suffix'Length then
         return False;
      end if;
      return To_Lower (S (S'Last - Suffix'Length + 1 .. S'Last))
        = To_Lower (Suffix);
   end Ends_With_Ignore_Case;

   function Csharp_Exe_Path_Matches (Output_Path : String) return Boolean is
   begin
      if Host_Is_Windows then
         return Ends_With_Ignore_Case (Output_Path, ".exe");
      end if;
      return Ada.Directories.Extension (Output_Path) = "";
   end Csharp_Exe_Path_Matches;

   function Dotnet_On_Path return Boolean is
      Path : constant GNAT.OS_Lib.String_Access :=
        Locate_Exec_On_Path ("dotnet");
   begin
      return Path /= null;
   end Dotnet_On_Path;

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
                (Base, "eml_dotnet_" & Img (Img'First + 1 .. Img'Last));
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

   function Run_Dotnet
     (Work_Dir : String; Args : in out Argument_List) return Integer
   is
      Dotnet : constant GNAT.OS_Lib.String_Access :=
        Locate_Exec_On_Path ("dotnet");
      Old    : constant String := Ada.Directories.Current_Directory;
      Code   : Integer;
   begin
      if Dotnet = null then
         Free_Args (Args);
         return 127;
      end if;
      Ada.Directories.Set_Directory (Work_Dir);
      Code := Spawn (Dotnet.all, Args);
      Ada.Directories.Set_Directory (Old);
      Free_Args (Args);
      return Os_Exit_Code (Code);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old);
         Free_Args (Args);
         raise;
   end Run_Dotnet;

   function Run_Build (Work_Dir : String) return Integer is
      Copy : Argument_List :=
        Argument_List'
          (1 => new String'("build"),
           2 => new String'("Program.csproj"),
           3 => new String'("-c"),
           4 => new String'("Release"),
           5 => new String'("--nologo"),
           6 => new String'("-o"),
           7 => new String'("artifacts"));
   begin
      return Run_Dotnet (Work_Dir, Copy);
   end Run_Build;

   function Run_Publish (Work_Dir : String) return Integer is
      Rid  : constant String := Host_Runtime_Id;
      Copy : Argument_List :=
        Argument_List'
          (1 => new String'("publish"),
           2 => new String'("Program.csproj"),
           3 => new String'("-c"),
           4 => new String'("Release"),
           5 => new String'("-r"),
           6 => new String'(Rid),
           7 => new String'("--nologo"),
           8 => new String'("-p:PublishSingleFile=true"),
           9 => new String'("-p:RollForward=LatestMajor"),
           10 => new String'("--self-contained"),
           11 => new String'("false"),
           12 => new String'("-o"),
           13 => new String'("publish"));
   begin
      return Run_Dotnet (Work_Dir, Copy);
   end Run_Publish;

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

   function File_If_Exists (Dir, Name : String) return String is
      Path : constant String := Ada.Directories.Compose (Dir, Name);
   begin
      if Ada.Directories.Exists (Path) then
         return Path;
      end if;
      return "";
   end File_If_Exists;

   function Find_Built_Dll (Artifacts_Dir : String) return String is
   begin
      return File_If_Exists (Artifacts_Dir, "Program.dll");
   end Find_Built_Dll;

   function Find_Published_Exe (Publish_Dir : String) return String is
      Named  : constant String := File_If_Exists (Publish_Dir, "Program");
      Win    : constant String := File_If_Exists (Publish_Dir, "Program.exe");
      Search : Ada.Directories.Search_Type;
   begin
      if Host_Is_Windows then
         if Win'Length > 0 then
            return Win;
         end if;
         Ada.Directories.Start_Search (Search, Publish_Dir, "*.exe");
         while Ada.Directories.More_Entries (Search) loop
            declare
               Ent : Ada.Directories.Directory_Entry_Type;
            begin
               Ada.Directories.Get_Next_Entry (Search, Ent);
               declare
                  Simple : constant String :=
                    Ada.Directories.Simple_Name (Ent);
               begin
                  if Simple /= "apphost.exe" then
                     Ada.Directories.End_Search (Search);
                     return Ada.Directories.Compose (Publish_Dir, Simple);
                  end if;
               end;
            end;
         end loop;
         Ada.Directories.End_Search (Search);
         return "";
      end if;

      if Named'Length > 0 then
         return Named;
      end if;
      return "";
   end Find_Published_Exe;

   type Job_Kind is (Build_Program_Dll, Build_Lib_Dll, Publish_Exe);

   function Run_Job
     (Root             : IR_Eml.Node_Access;
      Meta             : IR_Eml.Dump_Meta;
      Function_Name    : String;
      Target_Framework : String;
      Kind             : Job_Kind;
      Output_Path      : String) return Build_Result
   is
      Result    : Build_Result;
      Temp_Dir  : constant String := Make_Temp_Dir;
      Cs_Path   : constant String :=
        Ada.Directories.Compose (Temp_Dir, "Program.cs");
      Artifacts : constant String :=
        Ada.Directories.Compose (Temp_Dir, "artifacts");
      Publish   : constant String :=
        Ada.Directories.Compose (Temp_Dir, "publish");
      Exit_Code : Integer;
   begin
      Result.Ok := False;
      Result.Error_Length := 0;

      begin
         Ada.Directories.Create_Directory (Temp_Dir);

         case Kind is
            when Build_Lib_Dll =>
               Write_CSharp_Lib_To_File
                 (Root, Meta, Cs_Path, Function_Name,
                  Target_Framework, True);
            when Build_Program_Dll | Publish_Exe =>
               Write_CSharp_Program_To_File
                 (Root, Meta, Cs_Path, Function_Name,
                  Target_Framework, True);
         end case;

         case Kind is
            when Build_Program_Dll | Build_Lib_Dll =>
               Exit_Code := Run_Build (Temp_Dir);
               if Exit_Code /= 0 then
                  Set_Error
                    (Result,
                     "dotnet build failed with exit code "
                     & Integer'Image (Exit_Code));
                  Ada.Directories.Delete_Tree (Temp_Dir);
                  return Result;
               end if;
               declare
                  Built : constant String := Find_Built_Dll (Artifacts);
               begin
                  if Built = "" then
                     Set_Error (Result, "dotnet build produced no .dll");
                     Ada.Directories.Delete_Tree (Temp_Dir);
                     return Result;
                  end if;
                  Ada.Directories.Copy_File (Built, Output_Path);
               end;
            when Publish_Exe =>
               if Host_Runtime_Id = "" then
                  Set_Error
                    (Result,
                     "dotnet publish: could not determine a "
                     & "runtime identifier for this OS");
                  Ada.Directories.Delete_Tree (Temp_Dir);
                  return Result;
               end if;
               Exit_Code := Run_Publish (Temp_Dir);
               if Exit_Code /= 0 then
                  Set_Error
                    (Result,
                     "dotnet publish failed with exit code "
                     & Integer'Image (Exit_Code));
                  Ada.Directories.Delete_Tree (Temp_Dir);
                  return Result;
               end if;
               declare
                  Built : constant String := Find_Published_Exe (Publish);
               begin
                  if Built = "" then
                     Set_Error
                       (Result, "dotnet publish produced no executable");
                     Ada.Directories.Delete_Tree (Temp_Dir);
                     return Result;
                  end if;
                  Ada.Directories.Copy_File (Built, Output_Path);
                  Make_Executable (Output_Path);
               end;
         end case;

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

   function Build_Csharp_Dll
     (Root             : IR_Eml.Node_Access;
      Meta             : IR_Eml.Dump_Meta;
      Output_Dll_Path  : String;
      Function_Name    : String;
      Target_Framework : String) return Build_Result
   is
   begin
      return Run_Job
        (Root, Meta, Function_Name, Target_Framework,
         Build_Program_Dll, Output_Dll_Path);
   end Build_Csharp_Dll;

   function Build_Csharp_Lib_Dll
     (Root             : IR_Eml.Node_Access;
      Meta             : IR_Eml.Dump_Meta;
      Output_Dll_Path  : String;
      Function_Name    : String;
      Target_Framework : String) return Build_Result
   is
   begin
      return Run_Job
        (Root, Meta, Function_Name, Target_Framework,
         Build_Lib_Dll, Output_Dll_Path);
   end Build_Csharp_Lib_Dll;

   function Publish_Csharp_Exe
     (Root             : IR_Eml.Node_Access;
      Meta             : IR_Eml.Dump_Meta;
      Output_Exe_Path  : String;
      Function_Name    : String;
      Target_Framework : String) return Build_Result
   is
   begin
      return Run_Job
        (Root, Meta, Function_Name, Target_Framework,
         Publish_Exe, Output_Exe_Path);
   end Publish_Csharp_Exe;

end Dotnet_Build;
