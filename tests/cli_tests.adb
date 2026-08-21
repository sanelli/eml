with Ada.Command_Line;
with Ada.Directories;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with Elm.CLI;
with Elm.Info;

package body CLI_Tests is

   use Ada.Strings.Unbounded;
   use type Ada.Command_Line.Exit_Status;

   procedure Run (Failed : in out Boolean) is

      procedure Require (Cond : Boolean; Message : String) is
      begin
         if not Cond then
            Failed := True;
            Ada.Text_IO.Put_Line ("FAIL: " & Message);
         end if;
      end Require;

      function Temp_Dir return String is
         (Ada.Directories.Compose
            (Ada.Directories.Current_Directory, "obj"));

      function Write_Temp (Name, Contents : String) return String is
         Path : constant String :=
           Ada.Directories.Compose (Temp_Dir, Name);
         File : Ada.Text_IO.File_Type;
      begin
         Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
         Ada.Text_IO.Put (File, Contents);
         Ada.Text_IO.Close (File);
         return Path;
      end Write_Temp;

      function Read_All (Path : String) return String is
         File   : Ada.Text_IO.File_Type;
         Buffer : Unbounded_String;
      begin
         Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
         while not Ada.Text_IO.End_Of_File (File) loop
            Append (Buffer, Ada.Text_IO.Get_Line (File));
            if not Ada.Text_IO.End_Of_File (File) then
               Append (Buffer, ASCII.LF);
            end if;
         end loop;
         Ada.Text_IO.Close (File);
         return To_String (Buffer);
      end Read_All;

      function A (S : String) return Unbounded_String is
        (To_Unbounded_String (S));

   begin
      declare
         In_Path  : constant String :=
           Write_Temp ("cli_ok.telm", "sin(pi+$X)");
         Out_Path : constant String :=
           Ada.Directories.Compose (Temp_Dir, "cli_ok.tokens");
         Args     : constant Elm.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("tokenize"),
            A ("-i"),
            A (In_Path),
            A ("-o"),
            A (Out_Path)];
         Status   : constant Ada.Command_Line.Exit_Status :=
           Elm.CLI.Run (Args);
         Expected : constant String :=
           "1:1 FUNCTION sin"
           & ASCII.LF
           & "1:4 LPAREN ("
           & ASCII.LF
           & "1:5 CONSTANT pi"
           & ASCII.LF
           & "1:7 PLUS +"
           & ASCII.LF
           & "1:8 VARIABLE $X"
           & ASCII.LF
           & "1:10 RPAREN )";
      begin
         Require (Status = Ada.Command_Line.Success, "cli-ok: exit");
         Require (Read_All (Out_Path) = Expected, "cli-ok: dump");
      end;

      declare
         In_Path  : constant String :=
           Write_Temp ("cli_long.telm", "1+2");
         Out_Path : constant String :=
           Ada.Directories.Compose (Temp_Dir, "cli_long.tokens");
         Args     : constant Elm.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("tokenize"),
            A ("--output"),
            A (Out_Path),
            A ("--input"),
            A (In_Path)];
         Status   : constant Ada.Command_Line.Exit_Status :=
           Elm.CLI.Run (Args);
      begin
         Require (Status = Ada.Command_Line.Success, "cli-long: exit");
         Require
           (Read_All (Out_Path) =
              "1:1 NUMBER 1" & ASCII.LF
              & "1:2 PLUS +" & ASCII.LF
              & "1:3 NUMBER 2",
            "cli-long: dump");
      end;

      declare
         In_Path  : constant String := Write_Temp ("cli_empty.telm", "");
         Out_Path : constant String :=
           Ada.Directories.Compose (Temp_Dir, "cli_empty.tokens");
         Args     : constant Elm.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("tokenize"),
            A ("-i"),
            A (In_Path),
            A ("-o"),
            A (Out_Path)];
         Status   : constant Ada.Command_Line.Exit_Status :=
           Elm.CLI.Run (Args);
      begin
         Require (Status = Ada.Command_Line.Success, "cli-empty: exit");
         Require (Read_All (Out_Path) = "", "cli-empty: dump");
      end;

      declare
         In_Path  : constant String :=
           Write_Temp ("cli_bad.telm", "1+@2");
         Out_Path : constant String :=
           Ada.Directories.Compose (Temp_Dir, "cli_bad.tokens");
         Args     : constant Elm.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("tokenize"),
            A ("-i"),
            A (In_Path),
            A ("-o"),
            A (Out_Path)];
         Status   : constant Ada.Command_Line.Exit_Status :=
           Elm.CLI.Run (Args);
      begin
         Require (Status = Ada.Command_Line.Failure, "cli-bad: exit");
         Require
           (Read_All (Out_Path) =
              "1:1 NUMBER 1" & ASCII.LF
              & "1:2 PLUS +" & ASCII.LF
              & "1:4 NUMBER 2",
            "cli-bad: dump");
      end;

      declare
         Args   : constant Elm.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("tokenize")];
         Status : constant Ada.Command_Line.Exit_Status :=
           Elm.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Failure, "cli-missing-i: exit");
      end;

      declare
         Args   : constant Elm.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("parse")];
         Status : constant Ada.Command_Line.Exit_Status :=
           Elm.CLI.Run (Args);
      begin
         Require (Status = Ada.Command_Line.Failure, "cli-parse: exit");
      end;

      declare
         In_Path : constant String :=
           Write_Temp ("cli_elm.elm", "elm(1,1)");
         Args    : constant Elm.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("tokenize"),
            A ("-i"),
            A (In_Path)];
         Status  : constant Ada.Command_Line.Exit_Status :=
           Elm.CLI.Run (Args);
      begin
         Require (Status = Ada.Command_Line.Failure, "cli-elm: exit");
      end;

      declare
         In_Path : constant String :=
           Write_Temp ("cli_outext.telm", "1");
         Args    : constant Elm.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("tokenize"),
            A ("-i"),
            A (In_Path),
            A ("-o"),
            A ("out.txt")];
         Status  : constant Ada.Command_Line.Exit_Status :=
           Elm.CLI.Run (Args);
      begin
         Require (Status = Ada.Command_Line.Failure, "cli-outext: exit");
      end;

      declare
         Args   : constant Elm.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("tokenize"),
            A ("-i"),
            A ("obj/does_not_exist.telm")];
         Status : constant Ada.Command_Line.Exit_Status :=
           Elm.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Failure, "cli-missing-file: exit");
      end;

      Require (Elm.Info.Program_Name = "elm", "info: name");
      Require (Elm.Info.Author = "Stefano Anelli", "info: author");
      Require (Elm.Info.Version'Length > 0, "info: version");
      Require (Elm.Info.Git_Commit'Length > 0, "info: commit");

      declare
         Args   : constant Elm.CLI.Arg_Array :=
           [A ("--no-logo"), A ("help")];
         Status : constant Ada.Command_Line.Exit_Status :=
           Elm.CLI.Run (Args);
      begin
         Require (Status = Ada.Command_Line.Success, "cli-help: exit");
      end;

      declare
         Args   : constant Elm.CLI.Arg_Array :=
           [A ("--no-logo"), A ("help"), A ("tokenize")];
         Status : constant Ada.Command_Line.Exit_Status :=
           Elm.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Success, "cli-help-tokenize: exit");
      end;

      declare
         Args   : constant Elm.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("help"),
            A ("compile")];
         Status : constant Ada.Command_Line.Exit_Status :=
           Elm.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Failure, "cli-help-unknown: exit");
      end;

      declare
         Args   : constant Elm.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("--input"),
            A ("samples/01_trig_basics.telm")];
         Status : constant Ada.Command_Line.Exit_Status :=
           Elm.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Failure, "cli-missing-cmd: exit");
      end;
   end Run;

end CLI_Tests;
