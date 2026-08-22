with Ada.Command_Line;
with Ada.Directories;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with Eml.CLI;
with Eml.Info;

package body CLI_Tests is

   use Ada.Streams;
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

      function Read_Bytes
        (Path : String; Count : Natural) return Stream_Element_Array
      is
         File   : Stream_IO.File_Type;
         Buffer : Stream_Element_Array
           (1 .. Stream_Element_Offset (Count));
         Last   : Stream_Element_Offset;
      begin
         Stream_IO.Open (File, Stream_IO.In_File, Path);
         Stream_IO.Read (File, Buffer, Last);
         Stream_IO.Close (File);
         return Buffer;
      end Read_Bytes;

      function A (S : String) return Unbounded_String is
        (To_Unbounded_String (S));

   begin
      declare
         In_Path  : constant String :=
           Write_Temp ("cli_ok.mxeml", "sin(pi+$X)");
         Out_Path : constant String :=
           Ada.Directories.Compose (Temp_Dir, "cli_ok.tokens");
         Args     : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("tokenize"),
            A ("-i"),
            A (In_Path),
            A ("-o"),
            A (Out_Path),
            A ("-v"),
            A ("$X=1"),
            A ("-w"),
            A ("none")];
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
           & "-- $X begin"
           & ASCII.LF
           & "1:8 NUMBER 1"
           & ASCII.LF
           & "-- $X end"
           & ASCII.LF
           & "1:10 RPAREN )";
      begin
         Require (Status = Ada.Command_Line.Success, "cli-ok: exit");
         Require (Read_All (Out_Path) = Expected, "cli-ok: dump");
      end;

      declare
         In_Path  : constant String :=
           Write_Temp ("cli_long.mxeml", "1+2");
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
         In_Path  : constant String := Write_Temp ("cli_empty.mxeml", "");
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
           Write_Temp ("cli_bad.mxeml", "1+@2");
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
           Write_Temp ("cli_parse_ok.mxeml", "1+2*3");
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
           Write_Temp ("cli_parse_md.mxeml", "1+2");
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
           Write_Temp ("cli_parse_dot.mxeml", "1+2");
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
           Write_Temp ("cli_parse_svg.mxeml", "1+2");
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
           Write_Temp ("cli_parse_badext.mxeml", "1");
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
           Write_Temp ("cli_parse_badfmt.mxeml", "1");
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
           Write_Temp ("cli_parse_lex.mxeml", "1+@2");
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
           Write_Temp ("cli_parse_err.mxeml", "1+");
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
           Write_Temp ("cli_outext.mxeml", "1");
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
            A ("obj/does_not_exist.mxeml")];
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
      Require
        (Ada.Strings.Fixed.Index
           (Eml.Info.Banner_Line,
            "EML compiler and interpreter - v0.1.")
         > 0,
         "info: banner prefix");
      Require
        (Ada.Strings.Fixed.Index
           (Eml.Info.Banner_Line, " - by Stefano Anelli")
         > 0,
         "info: banner suffix");

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
           (Status = Ada.Command_Line.Success, "cli-help-compile: exit");
      end;

      declare
         Args   : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("help"),
            A ("emlir")];
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
            A ("samples/01_trig_basics.mxeml")];
         Status : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Failure, "cli-missing-cmd: exit");
      end;

      declare
         In_Path  : constant String :=
           Write_Temp ("cli_preproc_id.mxeml", "1+2");
         Out_Path : constant String :=
           Ada.Directories.Compose (Temp_Dir, "cli_preproc_id.mxeml");
         Args     : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("preproc"),
            A ("-i"),
            A (In_Path),
            A ("-o"),
            A (Out_Path)];
         Status   : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require (Status = Ada.Command_Line.Success, "cli-preproc-id: exit");
         Require (Read_All (Out_Path) = "1+2", "cli-preproc-id: text");
      end;

      declare
         In_Path  : constant String :=
           Write_Temp ("cli_preproc_x.mxeml", "$X");
         Out_Path : constant String :=
           Ada.Directories.Compose (Temp_Dir, "cli_preproc_x.mxeml");
         Args     : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("preproc"),
            A ("-i"),
            A (In_Path),
            A ("-o"),
            A (Out_Path),
            A ("-v"),
            A ("$X=1+2")];
         Status   : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require (Status = Ada.Command_Line.Success, "cli-preproc-x: exit");
         Require (Read_All (Out_Path) = "1+2", "cli-preproc-x: text");
      end;

      declare
         In_Path : constant String :=
           Write_Temp ("cli_unbound.mxeml", "$X");
         Out_Path : constant String :=
           Ada.Directories.Compose (Temp_Dir, "cli_unbound.mxeml");
         Args    : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("preproc"),
            A ("-i"),
            A (In_Path),
            A ("-o"),
            A (Out_Path)];
         Status  : Ada.Command_Line.Exit_Status;
      begin
         if Ada.Directories.Exists (Out_Path) then
            Ada.Directories.Delete_File (Out_Path);
         end if;
         Status := Eml.CLI.Run (Args);
         Require (Status = Ada.Command_Line.Failure, "cli-unbound: exit");
         Require
           (not Ada.Directories.Exists (Out_Path),
            "cli-unbound: no file");
      end;

      declare
         In_Path : constant String :=
           Write_Temp ("cli_warn_err.mxeml", "1");
         Out_Path : constant String :=
           Ada.Directories.Compose (Temp_Dir, "cli_warn_err.tokens");
         Args    : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("tokenize"),
            A ("-i"),
            A (In_Path),
            A ("-o"),
            A (Out_Path),
            A ("-v"),
            A ("$Y=9"),
            A ("-w"),
            A ("error")];
         Status  : Ada.Command_Line.Exit_Status;
      begin
         if Ada.Directories.Exists (Out_Path) then
            Ada.Directories.Delete_File (Out_Path);
         end if;
         Status := Eml.CLI.Run (Args);
         Require (Status = Ada.Command_Line.Failure, "cli-warn-err: exit");
         Require
           (not Ada.Directories.Exists (Out_Path),
            "cli-warn-err: no file");
      end;

      declare
         In_Path : constant String :=
           Write_Temp ("cli_warn_bad.mxeml", "1");
         Args    : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("tokenize"),
            A ("-i"),
            A (In_Path),
            A ("-w"),
            A ("all")];
         Status  : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Failure, "cli-warn-bad: exit");
      end;

      declare
         In_Path : constant String :=
           Write_Temp ("cli_preproc_badext.mxeml", "1");
         Args    : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("preproc"),
            A ("-i"),
            A (In_Path),
            A ("-o"),
            A ("out.tokens")];
         Status  : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Failure, "cli-preproc-badext: exit");
      end;

      declare
         Args   : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"), A ("help"), A ("preproc")];
         Status : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Success, "cli-help-preproc: exit");
      end;

      declare
         In_Path  : constant String := Write_Temp ("cli_compile_e.mxeml", "e");
         Out_Path : constant String :=
           Ada.Directories.Compose (Temp_Dir, "cli_compile_e.beml");
         Args     : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("compile"),
            A ("-i"),
            A (In_Path),
            A ("-o"),
            A (Out_Path)];
         Status   : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
         Magic    : constant Stream_Element_Array := Read_Bytes (Out_Path, 4);
      begin
         Require (Status = Ada.Command_Line.Success, "cli-compile-beml: exit");
         Require
           (Magic (1) = Stream_Element'Val (16#42#)
            and then Magic (2) = Stream_Element'Val (16#45#)
            and then Magic (3) = Stream_Element'Val (16#4D#)
            and then Magic (4) = Stream_Element'Val (16#4C#),
            "cli-compile-beml: magic");
      end;

      declare
         In_Path  : constant String :=
           Write_Temp ("cli_compile_eml.mxeml", "e");
         Out_Path : constant String :=
           Ada.Directories.Compose (Temp_Dir, "cli_compile_eml.eml");
         Args     : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("compile"),
            A ("-i"),
            A (In_Path),
            A ("-o"),
            A (Out_Path),
            A ("-of"),
            A ("eml")];
         Status   : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
         Text     : constant String := Read_All (Out_Path);
      begin
         Require (Status = Ada.Command_Line.Success, "cli-compile-eml: exit");
         Require
           (Ada.Strings.Fixed.Index (Text, "-- Source:") > 0,
            "cli-compile-eml: header");
         Require
           (Ada.Strings.Fixed.Index (Text, "ONE") > 0
            and then Ada.Strings.Fixed.Index (Text, "EML") > 0,
            "cli-compile-eml: opcodes");
         Require
           (Ada.Strings.Fixed.Index (Text, " UTC") > 0,
            "cli-compile-eml: utc date");
      end;

      declare
         In_Path : constant String :=
           Write_Temp ("cli_compile_fmt.mxeml", "1");
         Out_Path : constant String :=
           Ada.Directories.Compose (Temp_Dir, "cli_compile_fmt.beml");
         Args    : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("compile"),
            A ("-i"),
            A (In_Path),
            A ("--output-format"),
            A ("beml"),
            A ("-o"),
            A (Out_Path)];
         Status  : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Success, "cli-compile-f-beml: exit");
      end;

      declare
         In_Path : constant String :=
           Write_Temp ("cli_compile_alias.mxeml", "1");
         Out_Path : constant String :=
           Ada.Directories.Compose (Temp_Dir, "cli_compile_alias.eml");
         Args    : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("compile"),
            A ("-i"),
            A (In_Path),
            A ("-of"),
            A ("eml"),
            A ("-o"),
            A (Out_Path)];
         Status  : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Success, "cli-compile-f-alias: exit");
      end;

      declare
         In_Path : constant String :=
           Write_Temp ("cli_compile_order.mxeml", "1");
         Out_Path : constant String :=
           Ada.Directories.Compose (Temp_Dir, "cli_compile_order.beml");
         Args    : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("compile"),
            A ("-o"),
            A (Out_Path),
            A ("-i"),
            A (In_Path)];
         Status  : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Success, "cli-compile-order: exit");
      end;

      declare
         In_Path : constant String :=
           Write_Temp ("cli_compile_var.mxeml", "1+$X");
         Out_Path : constant String :=
           Ada.Directories.Compose (Temp_Dir, "cli_compile_var.beml");
         Args    : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("compile"),
            A ("-i"),
            A (In_Path),
            A ("-o"),
            A (Out_Path),
            A ("-v"),
            A ("$X=1"),
            A ("-w"),
            A ("none")];
         Status  : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Success, "cli-compile-var: exit");
      end;

      declare
         In_Path : constant String :=
           Write_Temp ("cli_compile_stdout.mxeml", "e");
         Args    : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("compile"),
            A ("-i"),
            A (In_Path),
            A ("-of"),
            A ("eml")];
         Status  : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Success, "cli-compile-stdout: exit");
      end;

      declare
         Args   : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"), A ("--no-color"), A ("compile")];
         Status : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Failure, "cli-compile-missing-i: exit");
      end;

      declare
         In_Path : constant String :=
           Write_Temp ("cli_compile_badin.eml", "eml(1,1)");
         Args    : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("compile"),
            A ("-i"),
            A (In_Path)];
         Status  : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Failure, "cli-compile-badin: exit");
      end;

      declare
         In_Path  : constant String :=
           Write_Temp ("cli_compile_mismatch.mxeml", "1");
         Out_Path : constant String :=
           Ada.Directories.Compose (Temp_Dir, "cli_compile_mismatch.eml");
         Args     : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("compile"),
            A ("-i"),
            A (In_Path),
            A ("-o"),
            A (Out_Path)];
         Status   : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Failure,
            "cli-compile-beml-eml-ext: exit");
      end;

      declare
         In_Path  : constant String :=
           Write_Temp ("cli_compile_mismatch2.mxeml", "1");
         Out_Path : constant String :=
           Ada.Directories.Compose (Temp_Dir, "cli_compile_mismatch2.beml");
         Args     : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("compile"),
            A ("-i"),
            A (In_Path),
            A ("-o"),
            A (Out_Path),
            A ("-of"),
            A ("eml")];
         Status   : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Failure,
            "cli-compile-eml-beml-ext: exit");
      end;

      declare
         In_Path : constant String :=
           Write_Temp ("cli_compile_of.mxeml", "1");
         Args    : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("compile"),
            A ("-i"),
            A (In_Path),
            A ("-of"),
            A ("md")];
         Status  : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Failure, "cli-compile-of: exit");
      end;

      declare
         In_Path : constant String :=
           Write_Temp ("cli_parse_format.mxeml", "1");
         Args    : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("parse"),
            A ("-i"),
            A (In_Path),
            A ("--output-format"),
            A ("eml")];
         Status  : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Failure, "cli-parse-format: exit");
      end;

      declare
         In_Path : constant String :=
           Write_Temp ("cli_compile_badfmt.mxeml", "1");
         Args    : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("compile"),
            A ("-i"),
            A (In_Path),
            A ("-of"),
            A ("cli")];
         Status  : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Failure, "cli-compile-badfmt: exit");
      end;

      declare
         In_Path : constant String :=
           Write_Temp ("cli_compile_dupfmt.mxeml", "1");
         Args    : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("compile"),
            A ("-i"),
            A (In_Path),
            A ("-of"),
            A ("eml"),
            A ("-of"),
            A ("beml")];
         Status  : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Failure, "cli-compile-dupfmt: exit");
      end;

      declare
         In_Path : constant String :=
           Write_Temp ("cli_compile_unbound.mxeml", "$X");
         Out_Path : constant String :=
           Ada.Directories.Compose (Temp_Dir, "cli_compile_unbound.beml");
         Args    : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("compile"),
            A ("-i"),
            A (In_Path),
            A ("-o"),
            A (Out_Path)];
         Status  : Ada.Command_Line.Exit_Status;
      begin
         if Ada.Directories.Exists (Out_Path) then
            Ada.Directories.Delete_File (Out_Path);
         end if;
         Status := Eml.CLI.Run (Args);
         Require
           (Status = Ada.Command_Line.Failure, "cli-compile-unbound: exit");
         Require
           (not Ada.Directories.Exists (Out_Path),
            "cli-compile-unbound: no file");
      end;

      declare
         In_Path : constant String :=
           Write_Temp ("cli_compile_lex.mxeml", "1+@2");
         Out_Path : constant String :=
           Ada.Directories.Compose (Temp_Dir, "cli_compile_lex.beml");
         Args    : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("compile"),
            A ("-i"),
            A (In_Path),
            A ("-o"),
            A (Out_Path)];
         Status  : Ada.Command_Line.Exit_Status;
      begin
         if Ada.Directories.Exists (Out_Path) then
            Ada.Directories.Delete_File (Out_Path);
         end if;
         Status := Eml.CLI.Run (Args);
         Require
           (Status = Ada.Command_Line.Failure, "cli-compile-lex: exit");
         Require
           (not Ada.Directories.Exists (Out_Path),
            "cli-compile-lex: no file");
      end;

      declare
         In_Path : constant String :=
           Write_Temp ("cli_compile_parse.mxeml", "1+");
         Out_Path : constant String :=
           Ada.Directories.Compose (Temp_Dir, "cli_compile_parse.beml");
         Args    : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("compile"),
            A ("-i"),
            A (In_Path),
            A ("-o"),
            A (Out_Path)];
         Status  : Ada.Command_Line.Exit_Status;
      begin
         if Ada.Directories.Exists (Out_Path) then
            Ada.Directories.Delete_File (Out_Path);
         end if;
         Status := Eml.CLI.Run (Args);
         Require
           (Status = Ada.Command_Line.Failure, "cli-compile-parse: exit");
         Require
           (not Ada.Directories.Exists (Out_Path),
            "cli-compile-parse: no file");
      end;

      declare
         Args   : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"), A ("--no-color"), A ("emlir")];
         Status : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Failure, "cli-unknown-cmd: exit");
      end;

      declare
         Args   : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"), A ("help"), A ("run")];
         Status : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Success, "cli-help-run: exit");
      end;

      declare
         In_Path : constant String :=
           Write_Temp ("cli_run_one.mxeml", "1");
         Args    : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("run"),
            A ("-i"),
            A (In_Path)];
         Status  : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Success, "cli-run-mxeml-1: exit");
      end;

      declare
         In_Path : constant String :=
           Write_Temp ("cli_run_e.mxeml", "e");
         Args    : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("run"),
            A ("-i"),
            A (In_Path)];
         Status  : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Success, "cli-run-mxeml-e: exit");
      end;

      declare
         In_Path : constant String :=
           Write_Temp ("cli_run_e.teml", "eml(1, 1)");
         Args    : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("run"),
            A ("-i"),
            A (In_Path)];
         Status  : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Success, "cli-run-teml: exit");
      end;

      declare
         In_Path : constant String :=
           Write_Temp ("cli_run_one.eml", "ONE");
         Args    : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("run"),
            A ("-i"),
            A (In_Path)];
         Status  : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Success, "cli-run-eml-one: exit");
      end;

      declare
         In_Path : constant String :=
           Write_Temp
             ("cli_run_e.eml",
              "ONE" & ASCII.LF & "ONE" & ASCII.LF & "EML");
         Args    : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("run"),
            A ("-i"),
            A (In_Path)];
         Status  : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Success, "cli-run-eml-e: exit");
      end;

      declare
         In_Path  : constant String :=
           Write_Temp ("cli_run_beml.mxeml", "1");
         Beml_Path : constant String :=
           Ada.Directories.Compose (Temp_Dir, "cli_run_beml.beml");
         C_Args   : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("compile"),
            A ("-i"),
            A (In_Path),
            A ("-o"),
            A (Beml_Path)];
         R_Args   : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("run"),
            A ("-i"),
            A (Beml_Path)];
         Status   : Ada.Command_Line.Exit_Status;
      begin
         Status := Eml.CLI.Run (C_Args);
         Require
           (Status = Ada.Command_Line.Success, "cli-run-beml: compile");
         Status := Eml.CLI.Run (R_Args);
         Require
           (Status = Ada.Command_Line.Success, "cli-run-beml: exit");
      end;

      declare
         In_Path : constant String :=
           Write_Temp ("cli_run_var.mxeml", "$X");
         Args    : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("run"),
            A ("-i"),
            A (In_Path),
            A ("-v"),
            A ("$X=1"),
            A ("-w"),
            A ("none")];
         Status  : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Success, "cli-run-mxeml-var: exit");
      end;

      declare
         In_Path : constant String :=
           Write_Temp ("cli_run_var.teml", "eml($X, 1)");
         Args    : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("run"),
            A ("-i"),
            A (In_Path),
            A ("-v"),
            A ("$X=1"),
            A ("-w"),
            A ("none")];
         Status  : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Success, "cli-run-teml-var: exit");
      end;

      declare
         Args   : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("run"),
            A ("-if"),
            A ("mxeml")];
         Status : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args, "1");
      begin
         Require
           (Status = Ada.Command_Line.Success, "cli-run-stdin: exit");
      end;

      declare
         In_Path  : constant String :=
           Write_Temp ("cli_run_stdin_b.mxeml", "1");
         Beml_Path : constant String :=
           Ada.Directories.Compose (Temp_Dir, "cli_run_stdin.beml");
         C_Args   : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("compile"),
            A ("-i"),
            A (In_Path),
            A ("-o"),
            A (Beml_Path)];
         R_Args   : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("run"),
            A ("-if"),
            A ("beml")];
         Status   : Ada.Command_Line.Exit_Status;
         Sz       : Natural;
      begin
         Status := Eml.CLI.Run (C_Args);
         Require
           (Status = Ada.Command_Line.Success,
            "cli-run-stdin-beml: compile");
         Sz := Natural (Ada.Directories.Size (Beml_Path));
         Status := Eml.CLI.Run (R_Args, Read_Bytes (Beml_Path, Sz));
         Require
           (Status = Ada.Command_Line.Success,
            "cli-run-stdin-beml: exit");
      end;

      declare
         In_Path : constant String :=
           Write_Temp ("cli_run_o.mxeml", "1");
         Args    : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("run"),
            A ("-i"),
            A (In_Path),
            A ("-o"),
            A ("out.txt")];
         Status  : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Failure, "cli-run-o: exit");
      end;

      declare
         In_Path : constant String :=
           Write_Temp ("cli_run_of.mxeml", "1");
         Args    : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("run"),
            A ("-i"),
            A (In_Path),
            A ("-of"),
            A ("eml")];
         Status  : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Failure, "cli-run-of: exit");
      end;

      declare
         Args   : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"), A ("--no-color"), A ("run")];
         Status : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Failure,
            "cli-run-missing-if: exit");
      end;

      declare
         In_Path : constant String :=
           Write_Temp ("cli_run_lex.mxeml", "1+@2");
         Args    : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("run"),
            A ("-i"),
            A (In_Path)];
         Status  : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Failure, "cli-run-lex: exit");
      end;

      declare
         In_Path : constant String :=
           Write_Temp ("cli_run_parse.mxeml", "1+");
         Args    : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("run"),
            A ("-i"),
            A (In_Path)];
         Status  : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Failure, "cli-run-parse: exit");
      end;

      declare
         In_Path : constant String :=
           Write_Temp ("cli_run_unbound.mxeml", "$X");
         Args    : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("run"),
            A ("-i"),
            A (In_Path)];
         Status  : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Failure, "cli-run-unbound: exit");
      end;

      declare
         In_Path : constant String :=
           Write_Temp ("cli_run_unused.eml", "ONE");
         Args    : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("run"),
            A ("-i"),
            A (In_Path),
            A ("-v"),
            A ("$X=1"),
            A ("-w"),
            A ("error")];
         Status  : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Failure, "cli-run-unused: exit");
      end;

      declare
         In_Path : constant String :=
           Write_Temp ("cli_run_colon.mxeml", "1");
         Args    : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("run"),
            A ("-i"),
            A (In_Path),
            A ("$X:1")];
         Status  : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Failure, "cli-run-colon: exit");
      end;

      declare
         In_Path : constant String :=
           Write_Temp ("cli_run_badext.xyz", "1");
         Args    : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("run"),
            A ("-i"),
            A (In_Path)];
         Status  : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Failure, "cli-run-badext: exit");
      end;

      declare
         In_Path  : constant String :=
           Write_Temp ("cli_compile_js.mxeml", "e");
         Out_Path : constant String :=
           Ada.Directories.Compose (Temp_Dir, "cli_compile_js.js");
         Html_Path : constant String :=
           Ada.Directories.Compose (Temp_Dir, "cli_compile_js.html");
         Args     : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("compile"),
            A ("-i"),
            A (In_Path),
            A ("-of"),
            A ("js"),
            A ("-o"),
            A (Out_Path)];
         Status   : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
         Js_Text  : constant String := Read_All (Out_Path);
         Html_Text : constant String := Read_All (Html_Path);
      begin
         Require
           (Status = Ada.Command_Line.Success, "cli-compile-js: exit");
         Require
           (Ada.Strings.Fixed.Index (Js_Text, "function eml") > 0,
            "cli-compile-js: eml fn");
         Require
           (Ada.Strings.Fixed.Index (Js_Text, "function main") > 0,
            "cli-compile-js: main fn");
         Require
           (Ada.Strings.Fixed.Index (Js_Text, "eml(") > 0,
            "cli-compile-js: nested eml");
         Require
           (Ada.Strings.Fixed.Index (Html_Text, "mathjs") > 0,
            "cli-compile-js: html cdn");
         Require
           (Ada.Strings.Fixed.Index
              (Html_Text, "cli_compile_js.js")
            > 0,
            "cli-compile-js: html src");
         Require
           (Ada.Strings.Fixed.Index (Html_Text, "main()") > 0,
            "cli-compile-js: html main");
      end;

      declare
         In_Path  : constant String :=
           Write_Temp ("cli_compile_js_teml.teml", "eml(1, 1)");
         Out_Path : constant String :=
           Ada.Directories.Compose (Temp_Dir, "cli_compile_js_teml.js");
         Args     : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("compile"),
            A ("-i"),
            A (In_Path),
            A ("-of"),
            A ("js"),
            A ("-o"),
            A (Out_Path)];
         Status   : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Success,
            "cli-compile-js-teml: exit");
         Require
           (Ada.Directories.Exists
              (Ada.Directories.Compose
                 (Temp_Dir, "cli_compile_js_teml.html")),
            "cli-compile-js-teml: html");
      end;

      declare
         In_Path  : constant String :=
           Write_Temp
             ("cli_compile_js_eml.eml",
              "ONE" & ASCII.LF & "ONE" & ASCII.LF & "EML");
         Out_Path : constant String :=
           Ada.Directories.Compose (Temp_Dir, "cli_compile_js_eml.js");
         Args     : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("compile"),
            A ("-i"),
            A (In_Path),
            A ("-of"),
            A ("js"),
            A ("-o"),
            A (Out_Path)];
         Status   : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Success,
            "cli-compile-js-eml: exit");
      end;

      declare
         Mx_Path  : constant String :=
           Write_Temp ("cli_compile_js_beml.mxeml", "e");
         Beml_Path : constant String :=
           Ada.Directories.Compose (Temp_Dir, "cli_compile_js_beml.beml");
         Out_Path : constant String :=
           Ada.Directories.Compose
             (Temp_Dir, "cli_compile_js_from_beml.js");
         Status1  : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run
             ([A ("--no-logo"),
               A ("compile"),
               A ("-i"),
               A (Mx_Path),
               A ("-o"),
               A (Beml_Path)]);
         Status2  : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run
             ([A ("--no-logo"),
               A ("compile"),
               A ("-i"),
               A (Beml_Path),
               A ("-of"),
               A ("js"),
               A ("-o"),
               A (Out_Path)]);
      begin
         Require
           (Status1 = Ada.Command_Line.Success,
            "cli-compile-js-beml: beml exit");
         Require
           (Status2 = Ada.Command_Line.Success,
            "cli-compile-js-beml: js exit");
      end;

      declare
         In_Path  : constant String :=
           Write_Temp ("cli_compile_js_var.mxeml", "$X");
         Out_Path : constant String :=
           Ada.Directories.Compose (Temp_Dir, "cli_compile_js_var.js");
         Args     : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("compile"),
            A ("-i"),
            A (In_Path),
            A ("-v"),
            A ("$X=1"),
            A ("-of"),
            A ("js"),
            A ("-o"),
            A (Out_Path)];
         Status   : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Success,
            "cli-compile-js-var: exit");
      end;

      declare
         Args   : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("compile"),
            A ("-if"),
            A ("mxeml"),
            A ("-of"),
            A ("js")];
         Status : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args, "e");
      begin
         Require
           (Status = Ada.Command_Line.Success,
            "cli-compile-js-stdout: exit");
      end;

      declare
         In_Path  : constant String :=
           Write_Temp ("cli_compile_js_badext.mxeml", "1");
         Out_Path : constant String :=
           Ada.Directories.Compose (Temp_Dir, "cli_compile_js_badext.eml");
         Args     : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("compile"),
            A ("-i"),
            A (In_Path),
            A ("-of"),
            A ("js"),
            A ("-o"),
            A (Out_Path)];
         Status   : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Failure,
            "cli-compile-js-badext: exit");
      end;

      declare
         In_Path  : constant String :=
           Write_Temp ("cli_compile_js_lex.mxeml", "1+@2");
         Out_Path : constant String :=
           Ada.Directories.Compose (Temp_Dir, "cli_compile_js_lex.js");
         Html_Path : constant String :=
           Ada.Directories.Compose (Temp_Dir, "cli_compile_js_lex.html");
         Args     : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("compile"),
            A ("-i"),
            A (In_Path),
            A ("-of"),
            A ("js"),
            A ("-o"),
            A (Out_Path)];
         Status   : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Failure,
            "cli-compile-js-lex: exit");
         Require
           (not Ada.Directories.Exists (Out_Path),
            "cli-compile-js-lex: no js");
         Require
           (not Ada.Directories.Exists (Html_Path),
            "cli-compile-js-lex: no html");
      end;

      declare
         In_Path  : constant String :=
           Write_Temp ("cli_compile_js_unbound.mxeml", "$X");
         Out_Path : constant String :=
           Ada.Directories.Compose
             (Temp_Dir, "cli_compile_js_unbound.js");
         Html_Path : constant String :=
           Ada.Directories.Compose
             (Temp_Dir, "cli_compile_js_unbound.html");
         Args     : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("compile"),
            A ("-i"),
            A (In_Path),
            A ("-of"),
            A ("js"),
            A ("-o"),
            A (Out_Path)];
         Status   : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Failure,
            "cli-compile-js-unbound: exit");
         Require
           (not Ada.Directories.Exists (Out_Path),
            "cli-compile-js-unbound: no js");
         Require
           (not Ada.Directories.Exists (Html_Path),
            "cli-compile-js-unbound: no html");
      end;

      declare
         In_Path : constant String :=
           Write_Temp ("cli_compile_js_badfmt.mxeml", "1");
         Args    : constant Eml.CLI.Arg_Array :=
           [A ("--no-logo"),
            A ("--no-color"),
            A ("compile"),
            A ("-i"),
            A (In_Path),
            A ("-of"),
            A ("javascript")];
         Status  : constant Ada.Command_Line.Exit_Status :=
           Eml.CLI.Run (Args);
      begin
         Require
           (Status = Ada.Command_Line.Failure,
            "cli-compile-js-javascript: exit");
      end;
   end Run;

end CLI_Tests;
