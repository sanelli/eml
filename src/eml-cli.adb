with Ada.Calendar;
with Ada.Exceptions;
with Ada.Text_IO;

with Eml.Info;
with Expr_Lower;
with Expr_Preprocessor;
with Expr_Parser;
with Expr_Tokenizer;
with IR_Eml;

package body Eml.CLI is

   use Ada.Strings.Unbounded;
   use type Expr_Tokenizer.Diagnostic_Array_Access;
   use type Expr_Parser.Output_Format;
   use type IR_Eml.Output_Format;
   use Expr_Preprocessor;
   use type Ada.Command_Line.Exit_Status;

   Red_On    : constant String := ASCII.ESC & "[31m";
   Red_Off   : constant String := ASCII.ESC & "[0m";
   Yellow_On : constant String := ASCII.ESC & "[33m";
   Yellow_Off : constant String := ASCII.ESC & "[0m";

   Expected_Cmds : constant String :=
     "help, preproc, tokenize, parse, or compile";

   type Warn_Mode is (Default_Warn, No_Warn, Error_Warn);

   type Binding_List is array (Positive range <>) of Expr_Preprocessor.Binding;

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
        (Ada.Text_IO.Standard_Output, Eml.Info.Banner_Line);
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

   procedure Put_Stderr_Yellow (Text : String; Use_Color : Boolean) is
   begin
      if Use_Color then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error, Yellow_On & Text & Yellow_Off);
      else
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, Text);
      end if;
   end Put_Stderr_Yellow;

   function Var_Suffix
     (From_Var : Boolean; Var_Name : Unbounded_String) return String
   is
   begin
      if From_Var then
         return " (from " & To_String (Var_Name) & ")";
      end if;
      return "";
   end Var_Suffix;

   procedure Put_Usage_Lines (Use_Color : Boolean) is
   begin
      Put_Stderr ("Usage:", Use_Color);
      Put_Stderr ("  eml <command> [options]", Use_Color);
      Put_Stderr ("  eml help [command]", Use_Color);
      Put_Stderr
        ("  eml preproc --input|-i <file.teml> "
         & "[--output|-o <file.teml>] "
         & "[--var|-v $NAME=EXPR]... "
         & "[--warn|-w default|none|error] "
         & "[--no-color] [--no-logo]",
         Use_Color);
      Put_Stderr
        ("  eml tokenize --input|-i <file.teml> "
         & "[--output|-o <file.tokens>] "
         & "[--var|-v $NAME=EXPR]... "
         & "[--warn|-w default|none|error] "
         & "[--no-color] [--no-logo]",
         Use_Color);
      Put_Stderr
        ("  eml parse --input|-i <file.teml> "
         & "[--output|-o <file>] "
         & "[--output-format|-of mermaid|md|dot|svg] "
         & "[--var|-v $NAME=EXPR]... "
         & "[--warn|-w default|none|error] "
         & "[--no-color] [--no-logo]",
         Use_Color);
      Put_Stderr
        ("  eml compile --input|-i <file.teml> "
         & "[--output|-o <file>] "
         & "[--format|-f eml|beml] "
         & "[--var|-v $NAME=EXPR]... "
         & "[--warn|-w default|none|error] "
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
        ("  preproc    Substitute $VARNAME from --var bindings");
      Put_Stdout
        ("  tokenize   Dump the token stream of a .teml source file");
      Put_Stdout
        ("  parse      Dump the syntax tree of a .teml source file");
      Put_Stdout
        ("  compile    Lower a .teml file to EML IR (.beml or .eml)");
      Put_Stdout
        ("             (run is not implemented yet)");
      Put_Stdout ("");
      Put_Stdout ("Common options:");
      Put_Stdout
        ("  --var, -v $NAME=EXPR   Bind a preprocessor variable "
         & "(repeatable)");
      Put_Stdout
        ("  --warn, -w MODE        default (default), none, or error");
      Put_Stdout
        ("  --no-color   Plain stderr diagnostics (no ANSI color)");
      Put_Stdout
        ("  --no-logo    Suppress the startup banner on stdout");
      Put_Stdout ("");
      Put_Stdout ("Examples:");
      Put_Stdout ("  eml help");
      Put_Stdout ("  eml help preproc");
      Put_Stdout ("  eml preproc -i f.teml -v '$X=1+2'");
      Put_Stdout ("  eml tokenize -i filename.teml");
      Put_Stdout ("  eml parse -i filename.teml");
      Put_Stdout ("  eml compile -i filename.teml -o out.beml");
      Put_Stdout ("");
      Put_Stdout
        ("Exit status: 0 on success, 1 on CLI, I/O, preprocess, lex, "
         & "or parse errors.");
   end Put_General_Help;

   procedure Put_Compile_Help is
   begin
      Put_Stdout ("eml compile - lower a .teml file to EML IR");
      Put_Stdout ("");
      Put_Stdout ("Usage:");
      Put_Stdout
        ("  eml compile --input|-i <file.teml> "
         & "[--output|-o <file>] "
         & "[--format|-f eml|beml] "
         & "[--var|-v $NAME=EXPR]... "
         & "[--warn|-w default|none|error] "
         & "[--no-color] [--no-logo]");
      Put_Stdout ("");
      Put_Stdout ("Options:");
      Put_Stdout
        ("  --input, -i <file.teml>     Required input (.teml only)");
      Put_Stdout
        ("  --output, -o <file>         Optional output; stdout if omitted");
      Put_Stdout
        ("  --format, -f FMT            beml (default) or eml");
      Put_Stdout
        ("  --var, -v $NAME=EXPR        Preprocessor binding (repeatable)");
      Put_Stdout
        ("  --warn, -w MODE             default, none, or error");
      Put_Stdout
        ("  --no-color                  Plain stderr diagnostics");
      Put_Stdout
        ("  --no-logo                   Suppress the startup banner");
      Put_Stdout ("");
      Put_Stdout ("Output extensions must match --format:");
      Put_Stdout ("  beml -> .beml");
      Put_Stdout ("  eml  -> .eml");
      Put_Stdout ("");
      Put_Stdout ("Examples:");
      Put_Stdout ("  eml compile -i filename.teml -o other.beml");
      Put_Stdout ("  eml compile -i filename.teml -o other.eml -f eml");
      Put_Stdout ("  eml --no-logo compile -i f.teml -f eml");
      Put_Stdout ("");
      Put_Stdout
        ("Preprocessor runs first, then tokenize, parse, and IR lowering.");
      Put_Stdout
        ("Use --no-logo when piping binary .beml to stdout.");
      Put_Stdout
        ("Exit status: 0 on success, otherwise 1.");
   end Put_Compile_Help;

   procedure Put_Preproc_Help is
   begin
      Put_Stdout ("eml preproc - substitute $VARNAME in a .teml file");
      Put_Stdout ("");
      Put_Stdout ("Usage:");
      Put_Stdout
        ("  eml preproc --input|-i <file.teml> "
         & "[--output|-o <file.teml>] "
         & "[--var|-v $NAME=EXPR]... "
         & "[--warn|-w default|none|error] "
         & "[--no-color] [--no-logo]");
      Put_Stdout ("");
      Put_Stdout ("Options:");
      Put_Stdout
        ("  --input, -i <file.teml>     Required input file (.teml only)");
      Put_Stdout
        ("  --output, -o <file.teml>    Optional output; stdout if omitted");
      Put_Stdout
        ("  --var, -v $NAME=EXPR        Bind $NAME to EXPRESSION "
         & "(repeatable)");
      Put_Stdout
        ("  --warn, -w MODE             default, none, or error");
      Put_Stdout
        ("  --no-color                  Plain stderr diagnostics");
      Put_Stdout
        ("  --no-logo                   Suppress the startup banner");
      Put_Stdout ("");
      Put_Stdout ("Examples:");
      Put_Stdout ("  eml preproc -i f.teml -v '$X=1+2'");
      Put_Stdout
        ("  eml preproc -i f.teml -o out.teml -v '$X=1'");
      Put_Stdout
        ("  eml --no-logo preproc -i f.teml");
      Put_Stdout ("");
      Put_Stdout
        ("Unbound $VARNAME in the file is an error. Unused --var bindings "
         & "emit warnings unless --warn none.");
      Put_Stdout
        ("Exit status: 0 on success, otherwise 1.");
   end Put_Preproc_Help;

   procedure Put_Tokenize_Help is
   begin
      Put_Stdout ("eml tokenize - dump tokens from a .teml file");
      Put_Stdout ("");
      Put_Stdout ("Usage:");
      Put_Stdout
        ("  eml tokenize --input|-i <file.teml> "
         & "[--output|-o <file.tokens>] "
         & "[--var|-v $NAME=EXPR]... "
         & "[--warn|-w default|none|error] "
         & "[--no-color] [--no-logo]");
      Put_Stdout ("");
      Put_Stdout ("Options:");
      Put_Stdout
        ("  --input, -i <file.teml>     Required input file (.teml only)");
      Put_Stdout
        ("  --output, -o <file.tokens>  Optional token dump file;");
      Put_Stdout
        ("                             if omitted, tokens go to stdout");
      Put_Stdout
        ("  --var, -v $NAME=EXPR        Preprocessor binding (repeatable)");
      Put_Stdout
        ("  --warn, -w MODE             default, none, or error");
      Put_Stdout
        ("  --no-color                  Plain stderr diagnostics");
      Put_Stdout
        ("  --no-logo                   Suppress the startup banner");
      Put_Stdout ("");
      Put_Stdout ("Examples:");
      Put_Stdout ("  eml tokenize -i filename.teml");
      Put_Stdout
        ("  eml tokenize -i f.teml -v '$X=1' -o other.tokens");
      Put_Stdout
        ("  eml --no-logo tokenize -i filename.teml");
      Put_Stdout ("");
      Put_Stdout
        ("Preprocessor runs first. Token dumps mark substituted spans "
         & "with -- $NAME begin/end comment lines.");
      Put_Stdout
        ("Invalid tokens are reported on stderr; scanning continues.");
      Put_Stdout
        ("Exit status: 0 if no preprocess or lex errors, otherwise 1.");
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
         & "[--var|-v $NAME=EXPR]... "
         & "[--warn|-w default|none|error] "
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
        ("  --var, -v $NAME=EXPR         Preprocessor binding (repeatable)");
      Put_Stdout
        ("  --warn, -w MODE              default, none, or error");
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
        ("Preprocessor runs first. Lex and parse errors are reported on "
         & "stderr; no tree is written on failure.");
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

   procedure Write_Text (Path : String; Text : String) is
      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put (File, Text);
      Ada.Text_IO.Close (File);
   end Write_Text;

   function Parse_Warn_Mode
     (S : String; Ok : out Boolean) return Warn_Mode
   is
   begin
      Ok := True;
      if S = "default" then
         return Default_Warn;
      elsif S = "none" then
         return No_Warn;
      elsif S = "error" then
         return Error_Warn;
      else
         Ok := False;
         return Default_Warn;
      end if;
   end Parse_Warn_Mode;

   function Parse_Var_Binding
     (Text : String; Ok : out Boolean) return Expr_Preprocessor.Binding
   is
      Eq : Natural := 0;
   begin
      Ok := True;
      for I in Text'Range loop
         if Text (I) = '=' then
            Eq := I;
            exit;
         end if;
      end loop;
      if Eq = 0 then
         Ok := False;
         return (Null_Unbounded_String, Null_Unbounded_String);
      end if;
      if Eq = Text'First or else Eq = Text'Last then
         Ok := False;
         return (Null_Unbounded_String, Null_Unbounded_String);
      end if;
      declare
         Name  : constant String := Text (Text'First .. Eq - 1);
         Value : constant String := Text (Eq + 1 .. Text'Last);
      begin
         if Name'Length = 0
           or else Name (Name'First) /= '$'
           or else Value'Length = 0
         then
            Ok := False;
            return (Null_Unbounded_String, Null_Unbounded_String);
         end if;
         return
           (Name  => To_Unbounded_String (Name),
            Value => To_Unbounded_String (Value));
      end;
   end Parse_Var_Binding;

   function Binding_Index
     (List : Binding_List; Count : Natural; Name : String) return Natural
   is
   begin
      for I in 1 .. Count loop
         if To_String (List (I).Name) = Name then
            return I;
         end if;
      end loop;
      return 0;
   end Binding_Index;

   function To_Binding_Array
     (List : Binding_List; Count : Natural) return Binding_Array
   is
      Result : Binding_Array (1 .. Count);
   begin
      for I in 1 .. Count loop
         Result (I) := List (I);
      end loop;
      return Result;
   end To_Binding_Array;

   function Preprocess_And_Check
     (Source    : String;
      Bindings  : Binding_Array;
      Warn      : Warn_Mode;
      Use_Color : Boolean;
      Prep      : out Expr_Preprocessor.Preprocess_Result)
      return Ada.Command_Line.Exit_Status
   is
      Unused_Error : Boolean := False;
   begin
      Prep := Expr_Preprocessor.Preprocess (Source, Bindings);

      if Prep.Unbound /= null then
         for D of Prep.Unbound.all loop
            Put_Stderr
              ("error: undefined variable "
               & To_String (D.Var_Name)
               & " at line "
               & Trim_Positive (D.Line)
               & ", column "
               & Trim_Positive (D.Column),
               Use_Color);
         end loop;
      end if;

      if Prep.Unused /= null then
         for Name of Prep.Unused.all loop
            case Warn is
               when Default_Warn =>
                  Put_Stderr_Yellow
                    ("warning: unused variable " & To_String (Name),
                     Use_Color);
               when No_Warn =>
                  null;
               when Error_Warn =>
                  Put_Stderr
                    ("error: unused variable " & To_String (Name),
                     Use_Color);
                  Unused_Error := True;
            end case;
         end loop;
      end if;

      if Prep.Had_Error or else Unused_Error then
         return Ada.Command_Line.Failure;
      end if;
      return Ada.Command_Line.Success;
   end Preprocess_And_Check;

   function Format_Lex_Message (D : Expr_Tokenizer.Diagnostic) return String
   is
   begin
      return To_String (D.Message)
        & Var_Suffix (D.From_Var, D.Var_Name);
   end Format_Lex_Message;

   function Format_Parse_Message (R : Expr_Parser.Parse_Result) return String
   is
   begin
      return To_String (R.Message)
        & Var_Suffix (R.From_Var, R.Var_Name);
   end Format_Parse_Message;

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

   function Parse_Compile_Format
     (S : String; Ok : out Boolean) return IR_Eml.Output_Format
   is
   begin
      Ok := True;
      if S = "eml" then
         return IR_Eml.Eml_Text;
      elsif S = "beml" then
         return IR_Eml.Beml_Binary;
      else
         Ok := False;
         return IR_Eml.Beml_Binary;
      end if;
   end Parse_Compile_Format;

   function Compile_Extension (Fmt : IR_Eml.Output_Format) return String is
   begin
      case Fmt is
         when IR_Eml.Eml_Text =>
            return ".eml";
         when IR_Eml.Beml_Binary =>
            return ".beml";
      end case;
   end Compile_Extension;

   function Run_Preproc
     (Input_Path  : String;
      Output_Path : String;
      Has_Output  : Boolean;
      Bindings    : Binding_Array;
      Warn        : Warn_Mode;
      Use_Color   : Boolean) return Ada.Command_Line.Exit_Status
   is
      Source : constant String := Read_File (Input_Path);
      Prep   : Expr_Preprocessor.Preprocess_Result;
      Status : Ada.Command_Line.Exit_Status;
   begin
      Status := Preprocess_And_Check (Source, Bindings, Warn, Use_Color, Prep);
      if Status /= Ada.Command_Line.Success then
         return Status;
      end if;

      if Has_Output then
         Write_Text (Output_Path, To_String (Prep.Text));
      else
         Ada.Text_IO.Put (Ada.Text_IO.Standard_Output, To_String (Prep.Text));
      end if;
      return Ada.Command_Line.Success;
   end Run_Preproc;

   function Run_Tokenize
     (Input_Path  : String;
      Output_Path : String;
      Has_Output  : Boolean;
      Bindings    : Binding_Array;
      Warn        : Warn_Mode;
      Use_Color   : Boolean) return Ada.Command_Line.Exit_Status
   is
      Source : constant String := Read_File (Input_Path);
      Prep   : Expr_Preprocessor.Preprocess_Result;
      Status : Ada.Command_Line.Exit_Status;
      Result : Expr_Tokenizer.Tokenize_Result;
   begin
      Status := Preprocess_And_Check (Source, Bindings, Warn, Use_Color, Prep);
      if Status /= Ada.Command_Line.Success then
         return Status;
      end if;

      Result :=
        Expr_Tokenizer.Tokenize
          (To_String (Prep.Text), Prep.Origins);

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
               & Format_Lex_Message (D),
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
      Bindings    : Binding_Array;
      Warn        : Warn_Mode;
      Use_Color   : Boolean) return Ada.Command_Line.Exit_Status
   is
      Source : constant String := Read_File (Input_Path);
      Prep   : Expr_Preprocessor.Preprocess_Result;
      Status : Ada.Command_Line.Exit_Status;
      Tok    : Expr_Tokenizer.Tokenize_Result;
   begin
      Status := Preprocess_And_Check (Source, Bindings, Warn, Use_Color, Prep);
      if Status /= Ada.Command_Line.Success then
         return Status;
      end if;

      Tok :=
        Expr_Tokenizer.Tokenize
          (To_String (Prep.Text), Prep.Origins);

      if Tok.Had_Errors then
         if Tok.Diagnostics /= null then
            for D of Tok.Diagnostics.all loop
               Put_Stderr
                 ("error: invalid token at line "
                  & Trim_Positive (D.Line)
                  & ", column "
                  & Trim_Positive (D.Column)
                  & ": "
                  & Format_Lex_Message (D),
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
               & Format_Parse_Message (Parsed),
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

   function Run_Emlir
     (Input_Path  : String;
      Output_Path : String;
      Has_Output  : Boolean;
      Fmt         : IR_Eml.Output_Format;
      Bindings    : Binding_Array;
      Warn        : Warn_Mode;
      Use_Color   : Boolean) return Ada.Command_Line.Exit_Status
   is
      Source : constant String := Read_File (Input_Path);
      Prep   : Expr_Preprocessor.Preprocess_Result;
      Status : Ada.Command_Line.Exit_Status;
      Tok    : Expr_Tokenizer.Tokenize_Result;
      Meta   : IR_Eml.Dump_Meta;
      IR     : IR_Eml.Node_Access;
   begin
      Status := Preprocess_And_Check (Source, Bindings, Warn, Use_Color, Prep);
      if Status /= Ada.Command_Line.Success then
         return Status;
      end if;

      Tok :=
        Expr_Tokenizer.Tokenize
          (To_String (Prep.Text), Prep.Origins);

      if Tok.Had_Errors then
         if Tok.Diagnostics /= null then
            for D of Tok.Diagnostics.all loop
               Put_Stderr
                 ("error: invalid token at line "
                  & Trim_Positive (D.Line)
                  & ", column "
                  & Trim_Positive (D.Column)
                  & ": "
                  & Format_Lex_Message (D),
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
               & Format_Parse_Message (Parsed),
               Use_Color);
            return Ada.Command_Line.Failure;
         end if;

         Meta :=
           (Source_Path => To_Unbounded_String (Input_Path),
            Version     => To_Unbounded_String (Eml.Info.Version),
            Compiled_At => Ada.Calendar.Clock);

         IR := Expr_Lower.Lower (Parsed.Root);

         case Fmt is
            when IR_Eml.Eml_Text =>
               if Has_Output then
                  IR_Eml.Write_Eml_To_File (IR, Meta, Output_Path);
               else
                  IR_Eml.Write_Eml_To_Stdout (IR, Meta);
               end if;
            when IR_Eml.Beml_Binary =>
               if Has_Output then
                  IR_Eml.Write_Beml_To_File (IR, Meta, Output_Path);
               else
                  IR_Eml.Write_Beml_To_Stdout (IR, Meta);
               end if;
         end case;
         return Ada.Command_Line.Success;
      end;
   end Run_Emlir;

   function Run (Args : Arg_Array) return Ada.Command_Line.Exit_Status is
      No_Color      : Boolean := False;
      No_Logo       : Boolean := False;
      Subcommand    : Unbounded_String;
      Topic         : Unbounded_String;
      Input_Path    : Unbounded_String;
      Output_Path   : Unbounded_String;
      Format_Text   : Unbounded_String;
      Compile_Text  : Unbounded_String;
      Warn_Text     : Unbounded_String := To_Unbounded_String ("default");
      Bindings      : Binding_List (1 .. 64);
      Binding_Count : Natural := 0;
      Have_Input    : Boolean := False;
      Have_Output   : Boolean := False;
      Have_Format   : Boolean := False;
      Have_Compile_Format : Boolean := False;
      Have_Warn     : Boolean := False;
      Have_Sub      : Boolean := False;
      Have_Topic    : Boolean := False;
      I             : Positive := 1;
      Use_Color     : Boolean;
      Cmd           : Unbounded_String;
      Fmt           : Expr_Parser.Output_Format := Expr_Parser.Mermaid;
      Compile_Fmt   : IR_Eml.Output_Format := IR_Eml.Beml_Binary;
      Format_Ok     : Boolean;
      Compile_Ok    : Boolean;
      Warn_Ok       : Boolean;
      Warn          : Warn_Mode := Default_Warn;
      Var_Ok        : Boolean;
      Binding       : Expr_Preprocessor.Binding;
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
            elsif A = "--format" or else A = "-f" then
               if Have_Compile_Format then
                  if not No_Logo then
                     Put_Banner;
                  end if;
                  Fail_CLI
                    ("error: repeated --format/-f", not No_Color);
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
               Compile_Text := Args (I + 1);
               Have_Compile_Format := True;
               I := I + 2;
            elsif A = "--var" or else A = "-v" then
               if I = Args'Last then
                  if not No_Logo then
                     Put_Banner;
                  end if;
                  Fail_CLI
                    ("error: missing value for " & A, not No_Color);
                  return Ada.Command_Line.Failure;
               end if;
               Binding := Parse_Var_Binding (To_String (Args (I + 1)), Var_Ok);
               if not Var_Ok then
                  if not No_Logo then
                     Put_Banner;
                  end if;
                  Fail_CLI
                    ("error: invalid --var/-v binding '"
                     & To_String (Args (I + 1))
                     & "' (expected $NAME=EXPRESSION)",
                     not No_Color);
                  return Ada.Command_Line.Failure;
               end if;
               if Binding_Index
                    (Bindings,
                     Binding_Count,
                     To_String (Binding.Name)) > 0
               then
                  if not No_Logo then
                     Put_Banner;
                  end if;
                  Fail_CLI
                    ("error: repeated --var/-v for "
                     & To_String (Binding.Name),
                     not No_Color);
                  return Ada.Command_Line.Failure;
               end if;
               if Binding_Count = Bindings'Length then
                  if not No_Logo then
                     Put_Banner;
                  end if;
                  Fail_CLI
                    ("error: too many --var/-v bindings", not No_Color);
                  return Ada.Command_Line.Failure;
               end if;
               Binding_Count := Binding_Count + 1;
               Bindings (Binding_Count) := Binding;
               I := I + 2;
            elsif A = "--warn" or else A = "-w" then
               if Have_Warn then
                  if not No_Logo then
                     Put_Banner;
                  end if;
                  Fail_CLI ("error: repeated --warn/-w", not No_Color);
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
               Warn_Text := Args (I + 1);
               Have_Warn := True;
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
      Warn := Parse_Warn_Mode (To_String (Warn_Text), Warn_Ok);

      if not No_Logo then
         Put_Banner;
      end if;

      if not Have_Sub then
         Fail_CLI
           ("error: missing command (expected " & Expected_Cmds & ")",
            Use_Color);
         return Ada.Command_Line.Failure;
      end if;

      if not Warn_Ok then
         Fail_CLI
           ("error: unknown warn mode '"
            & To_String (Warn_Text)
            & "' (expected default, none, or error)",
            Use_Color);
         return Ada.Command_Line.Failure;
      end if;

      if To_String (Cmd) = "help" then
         if not Have_Topic then
            Put_General_Help;
            return Ada.Command_Line.Success;
         elsif To_String (Topic) = "preproc" then
            Put_Preproc_Help;
            return Ada.Command_Line.Success;
         elsif To_String (Topic) = "tokenize" then
            Put_Tokenize_Help;
            return Ada.Command_Line.Success;
         elsif To_String (Topic) = "parse" then
            Put_Parse_Help;
            return Ada.Command_Line.Success;
         elsif To_String (Topic) = "compile" then
            Put_Compile_Help;
            return Ada.Command_Line.Success;
         else
            Fail_CLI
              ("error: unknown help topic '"
               & To_String (Topic)
               & "' (try: eml help preproc)",
               Use_Color);
            return Ada.Command_Line.Failure;
         end if;
      end if;

      if To_String (Cmd) /= "preproc"
        and then To_String (Cmd) /= "tokenize"
        and then To_String (Cmd) /= "parse"
        and then To_String (Cmd) /= "compile"
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

      if Have_Compile_Format and then To_String (Cmd) /= "compile" then
         Fail_CLI
           ("error: --format/-f is only valid for compile",
            Use_Color);
         return Ada.Command_Line.Failure;
      end if;

      if To_String (Cmd) = "compile" and then Have_Format then
         Fail_CLI
           ("error: --output-format/-of is not valid for compile",
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

      declare
         Binds : constant Binding_Array :=
           To_Binding_Array (Bindings, Binding_Count);
      begin
         if To_String (Cmd) = "preproc" then
            if Have_Output
              and then not Ends_With (To_String (Output_Path), ".teml")
            then
               Fail_CLI
                 ("error: output must be a .teml file", Use_Color);
               return Ada.Command_Line.Failure;
            end if;

            begin
               return Run_Preproc
                 (To_String (Input_Path),
                  To_String (Output_Path),
                  Have_Output,
                  Binds,
                  Warn,
                  Use_Color);
            exception
               when E : others =>
                  Put_Stderr
                    ("error: " & Ada.Exceptions.Exception_Message (E),
                     Use_Color);
                  return Ada.Command_Line.Failure;
            end;
         end if;

         if To_String (Cmd) = "tokenize" then
            if Have_Output
              and then not Ends_With (To_String (Output_Path), ".tokens")
            then
               Fail_CLI
                 ("error: output must be a .tokens file", Use_Color);
               return Ada.Command_Line.Failure;
            end if;

            begin
               return Run_Tokenize
                 (To_String (Input_Path),
                  To_String (Output_Path),
                  Have_Output,
                  Binds,
                  Warn,
                  Use_Color);
            exception
               when E : others =>
                  Put_Stderr
                    ("error: " & Ada.Exceptions.Exception_Message (E),
                     Use_Color);
                  return Ada.Command_Line.Failure;
            end;
         end if;

         if To_String (Cmd) = "compile" then
            if Have_Compile_Format then
               Compile_Fmt :=
                 Parse_Compile_Format (To_String (Compile_Text), Compile_Ok);
               if not Compile_Ok then
                  Fail_CLI
                    ("error: unknown compile format '"
                     & To_String (Compile_Text)
                     & "' (expected eml or beml)",
                     Use_Color);
                  return Ada.Command_Line.Failure;
               end if;
            end if;

            if Have_Output
              and then not Ends_With
                (To_String (Output_Path), Compile_Extension (Compile_Fmt))
            then
               Fail_CLI
                 ("error: output must end with "
                  & Compile_Extension (Compile_Fmt)
                  & " for format "
                  & (if Have_Compile_Format then To_String (Compile_Text)
                     else "beml"),
                  Use_Color);
               return Ada.Command_Line.Failure;
            end if;

            begin
               return Run_Emlir
                 (To_String (Input_Path),
                  To_String (Output_Path),
                  Have_Output,
                  Compile_Fmt,
                  Binds,
                  Warn,
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
               Binds,
               Warn,
               Use_Color);
         exception
            when E : others =>
               Put_Stderr
                 ("error: " & Ada.Exceptions.Exception_Message (E),
                  Use_Color);
               return Ada.Command_Line.Failure;
         end;
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
