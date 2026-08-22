with Ada.Exceptions;
with Ada.Text_IO;

with Eml.Info;
with Expr_Parser;
with Expr_Tokenizer;

package body Eml.CLI is

   use Ada.Strings.Unbounded;
   use type Expr_Tokenizer.Diagnostic_Array_Access;
   use type Expr_Parser.Output_Format;

   Red_On  : constant String := ASCII.ESC & "[31m";
   Red_Off : constant String := ASCII.ESC & "[0m";

   Expected_Cmds : constant String :=
     "help, tokenize, or parse";

   function Identity return String is
   begin
      return "eml";
   end Identity;

   function Trim_Positive (N : Positive) return String is
      S : constant String := Positive'Image (N);
   begin
      if S (S'First) = ' ' then
         return S (S'First + 1 .. S'Last);
      end if;
      return S;
   end Trim_Positive;

   function Ends_With (S, Suffix : String) return Boolean is
   begin
      return S'Length >= Suffix'Length
        and then S (S'Last - Suffix'Length + 1 .. S'Last) = Suffix;
   end Ends_With;

   function Starts_With_Dash (S : String) return Boolean is
     (S'Length > 0 and then S (S'First) = '-');

   procedure Put_Banner is
   begin
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Output,
         Eml.Info.Program_Name & "  " & Eml.Info.Version);
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Output,
         "Author: " & Eml.Info.Author);
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Output,
         "Commit: " & Eml.Info.Git_Commit);
   end Put_Banner;

   procedure Put_Stdout (Text : String) is
   begin
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Output, Text);
   end Put_Stdout;

   procedure Put_Stderr (Text : String; Use_Color : Boolean) is
   begin
      if Use_Color then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error, Red_On & Text & Red_Off);
      else
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, Text);
      end if;
   end Put_Stderr;

   procedure Put_Usage_Lines (Use_Color : Boolean) is
   begin
      Put_Stderr ("Usage:", Use_Color);
      Put_Stderr ("  eml <command> [options]", Use_Color);
      Put_Stderr ("  eml help [command]", Use_Color);
      Put_Stderr
        ("  eml tokenize --input|-i <file.teml> "
         & "[--output|-o <file.tokens>] [--no-color] [--no-logo]",
         Use_Color);
      Put_Stderr
        ("  eml parse --input|-i <file.teml> "
         & "[--output|-o <file>] "
         & "[--output-format|-of mermaid|md|dot|svg] "
         & "[--no-color] [--no-logo]",
         Use_Color);
   end Put_Usage_Lines;

   procedure Put_General_Help is
   begin
      Put_Stdout ("eml - EML compiler and interpreter");
      Put_Stdout ("");
      Put_Stdout ("Usage:");
      Put_Stdout ("  eml <command> [options]");
      Put_Stdout ("  eml help [command]");
      Put_Stdout ("");
      Put_Stdout ("Commands:");
      Put_Stdout
        ("  help       Show this help, or help for a specific command");
      Put_Stdout
        ("  tokenize   Dump the token stream of a .teml source file");
      Put_Stdout
        ("  parse      Dump the syntax tree of a .teml source file");
      Put_Stdout
        ("             (compile and run are not implemented yet)");
      Put_Stdout ("");
      Put_Stdout ("Common options:");
      Put_Stdout
        ("  --no-color   Plain stderr diagnostics (no ANSI red)");
      Put_Stdout
        ("  --no-logo    Suppress the startup banner on stdout");
      Put_Stdout ("");
      Put_Stdout ("Examples:");
      Put_Stdout ("  eml help");
      Put_Stdout ("  eml help tokenize");
      Put_Stdout ("  eml help parse");
      Put_Stdout ("  eml tokenize -i filename.teml");
      Put_Stdout ("  eml parse -i filename.teml");
      Put_Stdout ("");
      Put_Stdout
        ("Exit status: 0 on success, 1 on CLI, I/O, lex, or parse "
         & "errors.");
   end Put_General_Help;

   procedure Put_Tokenize_Help is
   begin
      Put_Stdout ("eml tokenize - dump tokens from a .teml file");
      Put_Stdout ("");
      Put_Stdout ("Usage:");
      Put_Stdout
        ("  eml tokenize --input|-i <file.teml> "
         & "[--output|-o <file.tokens>] [--no-color] [--no-logo]");
      Put_Stdout ("");
      Put_Stdout ("Options:");
      Put_Stdout
        ("  --input, -i <file.teml>     Required input file (.teml only)");
      Put_Stdout
        ("  --output, -o <file.tokens>  Optional token dump file;");
      Put_Stdout
        ("                             if omitted, tokens go to stdout");
      Put_Stdout
        ("  --no-color                  Plain stderr diagnostics");
      Put_Stdout
        ("  --no-logo                   Suppress the startup banner");
      Put_Stdout ("");
      Put_Stdout ("Examples:");
      Put_Stdout ("  eml tokenize -i filename.teml");
      Put_Stdout
        ("  eml tokenize -i filename.teml -o other.tokens");
      Put_Stdout
        ("  eml --no-logo tokenize -i filename.teml");
      Put_Stdout ("");
      Put_Stdout
        ("Invalid tokens are reported on stderr; scanning continues.");
      Put_Stdout
        ("Exit status: 0 if no invalid tokens, otherwise 1.");
   end Put_Tokenize_Help;

   procedure Put_Parse_Help is
   begin
      Put_Stdout ("eml parse - dump the syntax tree from a .teml file");
      Put_Stdout ("");
      Put_Stdout ("Usage:");
      Put_Stdout
        ("  eml parse --input|-i <file.teml> "
         & "[--output|-o <file>] "
         & "[--output-format|-of mermaid|md|dot|svg] "
         & "[--no-color] [--no-logo]");
      Put_Stdout ("");
      Put_Stdout ("Options:");
      Put_Stdout
        ("  --input, -i <file.teml>       Required input (.teml only)");
      Put_Stdout
        ("  --output, -o <file>          Optional dump file; if omitted,");
      Put_Stdout
        ("                               the tree goes to stdout");
      Put_Stdout
        ("  --output-format, -of <fmt>   mermaid (default), md, dot, svg");
      Put_Stdout
        ("  --no-color                   Plain stderr diagnostics");
      Put_Stdout
        ("  --no-logo                    Suppress the startup banner");
      Put_Stdout ("");
      Put_Stdout ("Output extensions must match the format:");
      Put_Stdout ("  mermaid -> .syntaxtree");
      Put_Stdout ("  md      -> .md");
      Put_Stdout ("  dot     -> .dot");
      Put_Stdout ("  svg     -> .svg");
      Put_Stdout ("");
      Put_Stdout ("Examples:");
      Put_Stdout ("  eml parse -i filename.teml");
      Put_Stdout
        ("  eml parse -i filename.teml -o other.syntaxtree");
      Put_Stdout
        ("  eml parse -i filename.teml -of md -o other.md");
      Put_Stdout
        ("  eml --no-logo parse -i filename.teml -of svg -o t.svg");
      Put_Stdout ("");
      Put_Stdout
        ("Lex and parse errors are reported on stderr; no tree is "
         & "written on failure.");
      Put_Stdout
        ("Exit status: 0 on success, otherwise 1.");
   end Put_Parse_Help;

   procedure Fail_CLI (Message : String; Use_Color : Boolean) is
   begin
      Put_Stderr (Message, Use_Color);
      Put_Usage_Lines (Use_Color);
      Put_Stderr ("Try 'eml help' for more information.", Use_Color);
   end Fail_CLI;

   function Read_File (Path : String) return String is
      File   : Ada.Text_IO.File_Type;
      Buffer : Unbounded_String;
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      begin
         while not Ada.Text_IO.End_Of_File (File) loop
            Append (Buffer, Ada.Text_IO.Get_Line (File));
            if not Ada.Text_IO.End_Of_File (File) then
               Append (Buffer, ASCII.LF);
            end if;
         end loop;
      exception
         when others =>
            Ada.Text_IO.Close (File);
            raise;
      end;
      Ada.Text_IO.Close (File);
      return To_String (Buffer);
   end Read_File;

   function Parse_Format
     (S : String; Ok : out Boolean) return Expr_Parser.Output_Format
   is
   begin
      Ok := True;
      if S = "mermaid" then
         return Expr_Parser.Mermaid;
      elsif S = "md" then
         return Expr_Parser.Markdown;
      elsif S = "dot" then
         return Expr_Parser.Dot;
      elsif S = "svg" then
         return Expr_Parser.Svg;
      else
         Ok := False;
         return Expr_Parser.Mermaid;
      end if;
   end Parse_Format;

   function Format_Extension (Fmt : Expr_Parser.Output_Format) return String
   is
   begin
      case Fmt is
         when Expr_Parser.Mermaid =>
            return ".syntaxtree";
         when Expr_Parser.Markdown =>
            return ".md";
         when Expr_Parser.Dot =>
            return ".dot";
         when Expr_Parser.Svg =>
            return ".svg";
      end case;
   end Format_Extension;

   function Run_Tokenize
     (Input_Path  : String;
      Output_Path : String;
      Has_Output  : Boolean;
      Use_Color   : Boolean) return Ada.Command_Line.Exit_Status
   is
      Source : constant String := Read_File (Input_Path);
      Result : constant Expr_Tokenizer.Tokenize_Result :=
        Expr_Tokenizer.Tokenize (Source);
   begin
      if Has_Output then
         declare
            File : Ada.Text_IO.File_Type;
         begin
            Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Output_Path);
            Expr_Tokenizer.Write_Dump (Result.Tokens.all, File);
            Ada.Text_IO.Close (File);
         end;
      else
         Expr_Tokenizer.Write_Dump_To_Stdout (Result.Tokens.all);
      end if;

      if Result.Diagnostics /= null then
         for D of Result.Diagnostics.all loop
            Put_Stderr
              ("error: invalid token at line "
               & Trim_Positive (D.Line)
               & ", column "
               & Trim_Positive (D.Column)
               & ": "
               & To_String (D.Message),
               Use_Color);
         end loop;
      end if;

      if Result.Had_Errors then
         return Ada.Command_Line.Failure;
      end if;
      return Ada.Command_Line.Success;
   end Run_Tokenize;

   function Run_Parse
     (Input_Path  : String;
      Output_Path : String;
      Has_Output  : Boolean;
      Fmt         : Expr_Parser.Output_Format;
      Use_Color   : Boolean) return Ada.Command_Line.Exit_Status
   is
      Source : constant String := Read_File (Input_Path);
      Tok    : constant Expr_Tokenizer.Tokenize_Result :=
        Expr_Tokenizer.Tokenize (Source);
   begin
      if Tok.Had_Errors then
         if Tok.Diagnostics /= null then
            for D of Tok.Diagnostics.all loop
               Put_Stderr
                 ("error: invalid token at line "
                  & Trim_Positive (D.Line)
                  & ", column "
                  & Trim_Positive (D.Column)
                  & ": "
                  & To_String (D.Message),
                  Use_Color);
            end loop;
         end if;
         return Ada.Command_Line.Failure;
      end if;

      declare
         Parsed : constant Expr_Parser.Parse_Result :=
           Expr_Parser.Parse (Tok.Tokens.all);
      begin
         if Parsed.Had_Error then
            Put_Stderr
              ("error: parse error at line "
               & Trim_Positive (Parsed.Error_Line)
               & ", column "
               & Trim_Positive (Parsed.Error_Col)
               & ": "
               & To_String (Parsed.Message),
               Use_Color);
            return Ada.Command_Line.Failure;
         end if;

         if Has_Output then
            Expr_Parser.Write_To_File
              (Parsed.Root, Fmt, Output_Path);
         else
            Expr_Parser.Write_To_Stdout (Parsed.Root, Fmt);
         end if;
         return Ada.Command_Line.Success;
      end;
   end Run_Parse;

   function Run (Args : Arg_Array) return Ada.Command_Line.Exit_Status is
      No_Color     : Boolean := False;
      No_Logo      : Boolean := False;
      Subcommand   : Unbounded_String;
      Topic        : Unbounded_String;
      Input_Path   : Unbounded_String;
      Output_Path  : Unbounded_String;
      Format_Text  : Unbounded_String;
      Have_Input   : Boolean := False;
      Have_Output  : Boolean := False;
      Have_Format  : Boolean := False;
      Have_Sub     : Boolean := False;
      Have_Topic   : Boolean := False;
      I            : Positive := 1;
      Use_Color    : Boolean;
      Cmd          : Unbounded_String;
      Fmt          : Expr_Parser.Output_Format := Expr_Parser.Mermaid;
      Format_Ok    : Boolean;
   begin
      I := Args'First;
      while I <= Args'Last loop
         declare
            A : constant String := To_String (Args (I));
         begin
            if A = "--no-color" then
               No_Color := True;
               I := I + 1;
            elsif A = "--no-logo" then
               No_Logo := True;
               I := I + 1;
            elsif not Have_Sub then
               if Starts_With_Dash (A) then
                  if not No_Logo then
                     Put_Banner;
                  end if;
                  Fail_CLI
                    ("error: missing command "
                     & "(expected "
                     & Expected_Cmds
                     & "); got '"
                     & A
                     & "'",
                     not No_Color);
                  return Ada.Command_Line.Failure;
               end if;
               Subcommand := Args (I);
               Have_Sub := True;
               I := I + 1;
            elsif To_String (Subcommand) = "help" then
               if Starts_With_Dash (A) then
                  if not No_Logo then
                     Put_Banner;
                  end if;
                  Fail_CLI
                    ("error: unexpected argument '" & A & "'",
                     not No_Color);
                  return Ada.Command_Line.Failure;
               end if;
               if Have_Topic then
                  if not No_Logo then
                     Put_Banner;
                  end if;
                  Fail_CLI
                    ("error: unexpected argument '" & A & "'",
                     not No_Color);
                  return Ada.Command_Line.Failure;
               end if;
               Topic := Args (I);
               Have_Topic := True;
               I := I + 1;
            elsif A = "--input" or else A = "-i" then
               if Have_Input then
                  if not No_Logo then
                     Put_Banner;
                  end if;
                  Fail_CLI ("error: repeated --input/-i", not No_Color);
                  return Ada.Command_Line.Failure;
               end if;
               if I = Args'Last then
                  if not No_Logo then
                     Put_Banner;
                  end if;
                  Fail_CLI
                    ("error: missing value for " & A, not No_Color);
                  return Ada.Command_Line.Failure;
               end if;
               Input_Path := Args (I + 1);
               Have_Input := True;
               I := I + 2;
            elsif A = "--output" or else A = "-o" then
               if Have_Output then
                  if not No_Logo then
                     Put_Banner;
                  end if;
                  Fail_CLI ("error: repeated --output/-o", not No_Color);
                  return Ada.Command_Line.Failure;
               end if;
               if I = Args'Last then
                  if not No_Logo then
                     Put_Banner;
                  end if;
                  Fail_CLI
                    ("error: missing value for " & A, not No_Color);
                  return Ada.Command_Line.Failure;
               end if;
               Output_Path := Args (I + 1);
               Have_Output := True;
               I := I + 2;
            elsif A = "--output-format" or else A = "-of" then
               if Have_Format then
                  if not No_Logo then
                     Put_Banner;
                  end if;
                  Fail_CLI
                    ("error: repeated --output-format/-of", not No_Color);
                  return Ada.Command_Line.Failure;
               end if;
               if I = Args'Last then
                  if not No_Logo then
                     Put_Banner;
                  end if;
                  Fail_CLI
                    ("error: missing value for " & A, not No_Color);
                  return Ada.Command_Line.Failure;
               end if;
               Format_Text := Args (I + 1);
               Have_Format := True;
               I := I + 2;
            else
               if not No_Logo then
                  Put_Banner;
               end if;
               Fail_CLI
                 ("error: unexpected argument '" & A & "'", not No_Color);
               return Ada.Command_Line.Failure;
            end if;
         end;
      end loop;

      Use_Color := not No_Color;
      Cmd := Subcommand;

      if not No_Logo then
         Put_Banner;
      end if;

      if not Have_Sub then
         Fail_CLI
           ("error: missing command (expected " & Expected_Cmds & ")",
            Use_Color);
         return Ada.Command_Line.Failure;
      end if;

      if To_String (Cmd) = "help" then
         if not Have_Topic then
            Put_General_Help;
            return Ada.Command_Line.Success;
         elsif To_String (Topic) = "tokenize" then
            Put_Tokenize_Help;
            return Ada.Command_Line.Success;
         elsif To_String (Topic) = "parse" then
            Put_Parse_Help;
            return Ada.Command_Line.Success;
         else
            Fail_CLI
              ("error: unknown help topic '"
               & To_String (Topic)
               & "' (try: eml help tokenize)",
               Use_Color);
            return Ada.Command_Line.Failure;
         end if;
      end if;

      if To_String (Cmd) /= "tokenize"
        and then To_String (Cmd) /= "parse"
      then
         Fail_CLI
           ("error: unknown command '"
            & To_String (Cmd)
            & "' (expected "
            & Expected_Cmds
            & ")",
            Use_Color);
         return Ada.Command_Line.Failure;
      end if;

      if Have_Format and then To_String (Cmd) /= "parse" then
         Fail_CLI
           ("error: --output-format/-of is only valid for parse",
            Use_Color);
         return Ada.Command_Line.Failure;
      end if;

      if not Have_Input then
         Fail_CLI ("error: missing --input/-i", Use_Color);
         return Ada.Command_Line.Failure;
      end if;

      if not Ends_With (To_String (Input_Path), ".teml") then
         Fail_CLI ("error: input must be a .teml file", Use_Color);
         return Ada.Command_Line.Failure;
      end if;

      if To_String (Cmd) = "tokenize" then
         if Have_Output
           and then not Ends_With (To_String (Output_Path), ".tokens")
         then
            Fail_CLI ("error: output must be a .tokens file", Use_Color);
            return Ada.Command_Line.Failure;
         end if;

         begin
            return Run_Tokenize
              (To_String (Input_Path),
               To_String (Output_Path),
               Have_Output,
               Use_Color);
         exception
            when E : others =>
               Put_Stderr
                 ("error: " & Ada.Exceptions.Exception_Message (E),
                  Use_Color);
               return Ada.Command_Line.Failure;
         end;
      end if;

      --  parse
      if Have_Format then
         Fmt := Parse_Format (To_String (Format_Text), Format_Ok);
         if not Format_Ok then
            Fail_CLI
              ("error: unknown output format '"
               & To_String (Format_Text)
               & "' (expected mermaid, md, dot, or svg)",
               Use_Color);
            return Ada.Command_Line.Failure;
         end if;
      end if;

      if Have_Output
        and then not Ends_With
          (To_String (Output_Path), Format_Extension (Fmt))
      then
         Fail_CLI
           ("error: output must end with "
            & Format_Extension (Fmt)
            & " for format "
            & (if Have_Format then To_String (Format_Text)
               else "mermaid"),
            Use_Color);
         return Ada.Command_Line.Failure;
      end if;

      begin
         return Run_Parse
           (To_String (Input_Path),
            To_String (Output_Path),
            Have_Output,
            Fmt,
            Use_Color);
      exception
         when E : others =>
            Put_Stderr
              ("error: " & Ada.Exceptions.Exception_Message (E),
               Use_Color);
            return Ada.Command_Line.Failure;
      end;
   end Run;

   procedure Run is
      Count  : constant Natural := Ada.Command_Line.Argument_Count;
      Args   : Arg_Array (1 .. Count);
      Status : Ada.Command_Line.Exit_Status;
   begin
      for J in 1 .. Count loop
         Args (J) :=
           To_Unbounded_String (Ada.Command_Line.Argument (J));
      end loop;
      Status := Run (Args);
      Ada.Command_Line.Set_Exit_Status (Status);
   end Run;

end Eml.CLI;
