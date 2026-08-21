with Ada.Exceptions;
with Ada.Text_IO;

with Elm.Info;
with Expr_Tokenizer;

package body Elm.CLI is

   use Ada.Strings.Unbounded;
   use type Expr_Tokenizer.Diagnostic_Array_Access;

   Red_On  : constant String := ASCII.ESC & "[31m";
   Red_Off : constant String := ASCII.ESC & "[0m";

   function Identity return String is
   begin
      return "elm";
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
         Elm.Info.Program_Name & "  " & Elm.Info.Version);
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Output,
         "Author: " & Elm.Info.Author);
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Output,
         "Commit: " & Elm.Info.Git_Commit);
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
      Put_Stderr ("  elm <command> [options]", Use_Color);
      Put_Stderr ("  elm help [command]", Use_Color);
      Put_Stderr
        ("  elm tokenize --input|-i <file.telm> "
         & "[--output|-o <file.tokens>] [--no-color] [--no-logo]",
         Use_Color);
   end Put_Usage_Lines;

   procedure Put_General_Help is
   begin
      Put_Stdout ("elm - ELM compiler and interpreter");
      Put_Stdout ("");
      Put_Stdout ("Usage:");
      Put_Stdout ("  elm <command> [options]");
      Put_Stdout ("  elm help [command]");
      Put_Stdout ("");
      Put_Stdout ("Commands:");
      Put_Stdout
        ("  help       Show this help, or help for a specific command");
      Put_Stdout
        ("  tokenize   Dump the token stream of a .telm source file");
      Put_Stdout
        ("             (parse, compile, and run are not implemented yet)");
      Put_Stdout ("");
      Put_Stdout ("Common options:");
      Put_Stdout
        ("  --no-color   Plain stderr diagnostics (no ANSI red)");
      Put_Stdout
        ("  --no-logo    Suppress the startup banner on stdout");
      Put_Stdout ("");
      Put_Stdout ("Examples:");
      Put_Stdout ("  elm help");
      Put_Stdout ("  elm help tokenize");
      Put_Stdout ("  elm tokenize -i filename.telm");
      Put_Stdout ("");
      Put_Stdout
        ("Exit status: 0 on success, 1 on CLI, I/O, or lex errors.");
   end Put_General_Help;

   procedure Put_Tokenize_Help is
   begin
      Put_Stdout ("elm tokenize - dump tokens from a .telm file");
      Put_Stdout ("");
      Put_Stdout ("Usage:");
      Put_Stdout
        ("  elm tokenize --input|-i <file.telm> "
         & "[--output|-o <file.tokens>] [--no-color] [--no-logo]");
      Put_Stdout ("");
      Put_Stdout ("Options:");
      Put_Stdout
        ("  --input, -i <file.telm>     Required input file (.telm only)");
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
      Put_Stdout ("  elm tokenize -i filename.telm");
      Put_Stdout
        ("  elm tokenize -i filename.telm -o other.tokens");
      Put_Stdout
        ("  elm --no-logo tokenize -i filename.telm");
      Put_Stdout ("");
      Put_Stdout
        ("Invalid tokens are reported on stderr; scanning continues.");
      Put_Stdout
        ("Exit status: 0 if no invalid tokens, otherwise 1.");
   end Put_Tokenize_Help;

   procedure Fail_CLI (Message : String; Use_Color : Boolean) is
   begin
      Put_Stderr (Message, Use_Color);
      Put_Usage_Lines (Use_Color);
      Put_Stderr ("Try 'elm help' for more information.", Use_Color);
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

   function Run (Args : Arg_Array) return Ada.Command_Line.Exit_Status is
      No_Color    : Boolean := False;
      No_Logo     : Boolean := False;
      Subcommand  : Unbounded_String;
      Topic       : Unbounded_String;
      Input_Path  : Unbounded_String;
      Output_Path : Unbounded_String;
      Have_Input  : Boolean := False;
      Have_Output : Boolean := False;
      Have_Sub    : Boolean := False;
      Have_Topic  : Boolean := False;
      I           : Positive := 1;
      Use_Color   : Boolean;
      Cmd         : Unbounded_String;
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
                     & "(expected help or tokenize); got '"
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
           ("error: missing command (expected help or tokenize)",
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
         else
            Fail_CLI
              ("error: unknown help topic '"
               & To_String (Topic)
               & "' (try: elm help tokenize)",
               Use_Color);
            return Ada.Command_Line.Failure;
         end if;
      end if;

      if To_String (Cmd) /= "tokenize" then
         Fail_CLI
           ("error: unknown command '"
            & To_String (Cmd)
            & "' (expected help or tokenize)",
            Use_Color);
         return Ada.Command_Line.Failure;
      end if;

      if not Have_Input then
         Fail_CLI ("error: missing --input/-i", Use_Color);
         return Ada.Command_Line.Failure;
      end if;

      if not Ends_With (To_String (Input_Path), ".telm") then
         Fail_CLI ("error: input must be a .telm file", Use_Color);
         return Ada.Command_Line.Failure;
      end if;

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

end Elm.CLI;
