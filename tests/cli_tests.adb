with Ada.Command_Line;
with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with Eml.CLI;
with Eml.Info;

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
           Write_Temp ("cli_ok.teml", "sin(pi+$X)");
         Out_Path : constant String :=
           Ada.Directories.Compose (Temp_Dir, "cli_ok.tokens");
         Args     : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("tokenize"),
            A ("-i"),
            A (In_Path),
            A ("-o"),
            A (Out_Path)];
         Status   : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
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
           Write_Temp ("cli_long.teml", "1+2");
         Out_Path : constant String :=
           Ada.Directories.Compose (Temp_Dir, "cli_long.tokens");
         Args     : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("tokenize"),
            A ("--output"),
            A (Out_Path),
            A ("--input"),
            A (In_Path)];
         Status   : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
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
         In_Path  : constant String := Write_Temp ("cli_empty.teml", "");
         Out_Path : constant String :=
           Ada.Directories.Compose (Temp_Dir, "cli_empty.tokens");
         Args     : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("tokenize"),
            A ("-i"),
            A (In_Path),
            A ("-o"),
            A (Out_Path)];
         Status   : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require (Status = Ada.Command_Line.Success, "cli-empty: exit");
         Require (Read_All (Out_Path) = "", "cli-empty: dump");
      end;

      declare
         In_Path  : constant String :=
           Write_Temp ("cli_bad.teml", "1+@2");
         Out_Path : constant String :=
           Ada.Directories.Compose (Temp_Dir, "cli_bad.tokens");
         Args     : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("tokenize"),
            A ("-i"),
            A (In_Path),
            A ("-o"),
            A (Out_Path)];
         Status   : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
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
         Args   : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("tokenize")];
         Status : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Failure, "cli-missing-i: exit");
      end;

      declare
         In_Path  : constant String :=
           Write_Temp ("cli_parse_ok.teml", "1+2*3");
         Out_Path : constant String :=
           Ada.Directories.Compose (Temp_Dir, "cli_parse_ok.syntaxtree");
         Args     : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("parse"),
            A ("-i"),
            A (In_Path),
            A ("-o"),
            A (Out_Path)];
         Status   : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
         Expected : constant String :=
           "flowchart TD"
           & ASCII.LF
           & "  n1[""+""]"
           & ASCII.LF
           & "  n2[""1""]"
           & ASCII.LF
           & "  n3[""*""]"
           & ASCII.LF
           & "  n4[""2""]"
           & ASCII.LF
           & "  n5[""3""]"
           & ASCII.LF
           & "  n1 --> n2"
           & ASCII.LF
           & "  n1 --> n3"
           & ASCII.LF
           & "  n3 --> n4"
           & ASCII.LF
           & "  n3 --> n5";
      begin
         Require (Status = Ada.Command_Line.Success, "cli-parse: exit");
         Require (Read_All (Out_Path) = Expected, "cli-parse: dump");
      end;

      declare
         In_Path  : constant String :=
           Write_Temp ("cli_parse_md.teml", "1+2");
         Out_Path : constant String :=
           Ada.Directories.Compose (Temp_Dir, "cli_parse_md.md");
         Args     : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("parse"),
            A ("--input"),
            A (In_Path),
            A ("--output"),
            A (Out_Path),
            A ("--output-format"),
            A ("md")];
         Status   : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
         Body_Txt : constant String := Read_All (Out_Path);
      begin
         Require (Status = Ada.Command_Line.Success, "cli-parse-md: exit");
         Require
           (Ada.Strings.Fixed.Index (Body_Txt, "# Syntax tree") = 1,
            "cli-parse-md: heading");
         Require
           (Ada.Strings.Fixed.Index (Body_Txt, "```mermaid") > 0,
            "cli-parse-md: fence");
      end;

      declare
         In_Path  : constant String :=
           Write_Temp ("cli_parse_dot.teml", "1+2");
         Out_Path : constant String :=
           Ada.Directories.Compose (Temp_Dir, "cli_parse_dot.dot");
         Args     : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("parse"),
            A ("-i"),
            A (In_Path),
            A ("-of"),
            A ("dot"),
            A ("-o"),
            A (Out_Path)];
         Status   : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Success, "cli-parse-dot: exit");
         Require
           (Ada.Strings.Fixed.Index
              (Read_All (Out_Path), "digraph syntaxtree") = 1,
            "cli-parse-dot: header");
      end;

      declare
         In_Path  : constant String :=
           Write_Temp ("cli_parse_svg.teml", "1+2");
         Out_Path : constant String :=
           Ada.Directories.Compose (Temp_Dir, "cli_parse_svg.svg");
         Args     : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("parse"),
            A ("-i"),
            A (In_Path),
            A ("-of"),
            A ("svg"),
            A ("-o"),
            A (Out_Path)];
         Status   : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Success, "cli-parse-svg: exit");
         Require
           (Ada.Strings.Fixed.Index (Read_All (Out_Path), "<svg") = 1,
            "cli-parse-svg: root");
      end;

      declare
         In_Path : constant String :=
           Write_Temp ("cli_parse_badext.teml", "1");
         Args    : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("parse"),
            A ("-i"),
            A (In_Path),
            A ("-of"),
            A ("mermaid"),
            A ("-o"),
            A ("out.md")];
         Status  : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Failure, "cli-parse-badext: exit");
      end;

      declare
         In_Path : constant String :=
           Write_Temp ("cli_parse_badfmt.teml", "1");
         Args    : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("parse"),
            A ("-i"),
            A (In_Path),
            A ("-of"),
            A ("json")];
         Status  : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Failure, "cli-parse-badfmt: exit");
      end;

      declare
         In_Path  : constant String :=
           Write_Temp ("cli_parse_lex.teml", "1+@2");
         Out_Path : constant String :=
           Ada.Directories.Compose
             (Temp_Dir, "cli_parse_lex.syntaxtree");
         Args     : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("parse"),
            A ("-i"),
            A (In_Path),
            A ("-o"),
            A (Out_Path)];
         Status   : Ada.Command_Line.Exit_Status;
      begin
         if Ada.Directories.Exists (Out_Path) then
            Ada.Directories.Delete_File (Out_Path);
         end if;
         Status := Eml.CLI.Run (Args);
         Require
           (Status = Ada.Command_Line.Failure, "cli-parse-lex: exit");
         Require
           (not Ada.Directories.Exists (Out_Path),
            "cli-parse-lex: no file");
      end;

      declare
         In_Path  : constant String :=
           Write_Temp ("cli_parse_err.teml", "1+");
         Out_Path : constant String :=
           Ada.Directories.Compose
             (Temp_Dir, "cli_parse_err.syntaxtree");
         Args     : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("parse"),
            A ("-i"),
            A (In_Path),
            A ("-o"),
            A (Out_Path)];
         Status   : Ada.Command_Line.Exit_Status;
      begin
         if Ada.Directories.Exists (Out_Path) then
            Ada.Directories.Delete_File (Out_Path);
         end if;
         Status := Eml.CLI.Run (Args);
         Require
           (Status = Ada.Command_Line.Failure, "cli-parse-err: exit");
         Require
           (not Ada.Directories.Exists (Out_Path),
            "cli-parse-err: no file");
      end;

      declare
         In_Path : constant String :=
           Write_Temp ("cli_parse_eml.eml", "eml(1,1)");
         Args    : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("parse"),
            A ("-i"),
            A (In_Path)];
         Status  : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Failure, "cli-parse-eml: exit");
      end;

      declare
         In_Path : constant String :=
           Write_Temp ("cli_eml.eml", "eml(1,1)");
         Args    : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("tokenize"),
            A ("-i"),
            A (In_Path)];
         Status  : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require (Status = Ada.Command_Line.Failure, "cli-eml: exit");
      end;

      declare
         In_Path : constant String :=
           Write_Temp ("cli_outext.teml", "1");
         Args    : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("tokenize"),
            A ("-i"),
            A (In_Path),
            A ("-o"),
            A ("out.txt")];
         Status  : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require (Status = Ada.Command_Line.Failure, "cli-outext: exit");
      end;

      declare
         Args   : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("tokenize"),
            A ("-i"),
            A ("obj/does_not_exist.teml")];
         Status : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Failure, "cli-missing-file: exit");
      end;

      Require (Eml.Info.Program_Name = "eml", "info: name");
      Require (Eml.Info.Author = "Stefano Anelli", "info: author");
      Require (Eml.Info.Version'Length > 0, "info: version");
      Require (Eml.Info.Git_Commit'Length > 0, "info: commit");

      declare
         Args   : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"), A ("help")];
         Status : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require (Status = Ada.Command_Line.Success, "cli-help: exit");
      end;

      declare
         Args   : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"), A ("help"), A ("tokenize")];
         Status : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Success, "cli-help-tokenize: exit");
      end;

      declare
         Args   : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"), A ("help"), A ("parse")];
         Status : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Success, "cli-help-parse: exit");
      end;

      declare
         Args   : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("help"),
            A ("compile")];
         Status : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Failure, "cli-help-unknown: exit");
      end;

      declare
         Args   : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("--input"),
            A ("samples/01_trig_basics.teml")];
         Status : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Failure, "cli-missing-cmd: exit");
      end;
   end Run;

end CLI_Tests;
