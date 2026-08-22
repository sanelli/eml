with Ada.Calendar;
with Ada.Exceptions;
with Ada.Streams.Stream_IO;
with Ada.Text_IO;

with Beml_Parser;
with Beml_Reader;
with Eml.Diagnostics;
with Eml.Info;
with Eml_Parser;
with Eml_Tokenizer;
with Expr_Lower;
with Expr_Preprocessor;
with Expr_Parser;
with Expr_Tokenizer;
with Interpreter;
with IR_Eml;
with Js_Backend;

use type Interpreter.Eval_Status;
with Teml_Parser;
with Teml_Tokenizer;

package body Eml.CLI is

   use Ada.Strings.Unbounded;
   use Eml.Diagnostics;
   use Expr_Preprocessor;
   use type Ada.Command_Line.Exit_Status;
   use type Expr_Parser.Output_Format;
   use type Expr_Tokenizer.Diagnostic_Array_Access;
   use type Expr_Tokenizer.Origin_Map_Access;
   use type Eml_Tokenizer.Diagnostic_Array_Access;
   use type IR_Eml.Tree_Output_Format;
   use type Teml_Tokenizer.Diagnostic_Array_Access;

   type Warn_Mode is (Default_Warn, No_Warn, Error_Warn);

   type Input_Format is (Mxeml, Teml, Stack_Eml, Beml);

   type Compile_Output_Format is (Eml_Text, Beml_Binary, Javascript);

   type Binding_List is array (Positive range <>) of Expr_Preprocessor.Binding;

   Empty_Stream : constant Ada.Streams.Stream_Element_Array (1 .. 0) := [];

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
        (Ada.Text_IO.Standard_Output, Info.Banner_Line);
   end Put_Banner;

   procedure Put_Stdout (Text : String) is
   begin
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Output, Text);
   end Put_Stdout;

   function Var_Suffix
     (From_Var : Boolean; Var_Name : Unbounded_String) return String
   is
   begin
      if From_Var then
         return " (from " & To_String (Var_Name) & ")";
      end if;
      return "";
   end Var_Suffix;

   function Common_Options return String is
   begin
      return
        "[--input|-i <file>] "
        & "[--input-format|-if mxeml|teml|eml|beml] "
        & "[--output|-o <file>] "
        & "[--var|-v $NAME=EXPR]... "
        & "[--warn|-w default|none|error] "
        & "[--no-color] [--no-logo]";
   end Common_Options;

   function Run_Options return String is
   begin
      return
        "[--input|-i <file>] "
        & "[--input-format|-if mxeml|teml|eml|beml] "
        & "[--var|-v $NAME=EXPR]... "
        & "[--warn|-w default|none|error] "
        & "[--no-color] [--no-logo]";
   end Run_Options;

   procedure Put_Usage_Lines (Use_Color : Boolean) is
   begin
      Emit_Error_Line ("Usage:", Use_Color);
      Emit_Error_Line ("  eml <command> [options]", Use_Color);
      Emit_Error_Line ("  eml help [command]", Use_Color);
      Emit_Error_Line
        ("  eml preproc "
         & Common_Options
         & " [--output-format|-of mxeml|teml]",
         Use_Color);
      Emit_Error_Line
        ("  eml tokenize "
         & Common_Options
         & " [--output-format|-of tokens]",
         Use_Color);
      Emit_Error_Line
        ("  eml parse "
         & Common_Options
         & " [--output-format|-of mermaid|md|dot|svg]",
         Use_Color);
      Emit_Error_Line
        ("  eml compile "
         & Common_Options
         & " [--output-format|-of eml|beml|js]",
         Use_Color);
      Emit_Error_Line
        ("  eml run "
         & Run_Options,
         Use_Color);
   end Put_Usage_Lines;

   procedure Fail_CLI
     (Id        : Diagnostic_Id;
      Use_Color : Boolean;
      Param1    : String := "";
      Param2    : String := "")
   is
   begin
      Emit_Error_Line (Format_Line (Id, 0, 0, Param1, Param2), Use_Color);
      Put_Usage_Lines (Use_Color);
      Emit_Error_Line ("Try 'eml help' for more information.", Use_Color);
   end Fail_CLI;

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
      Put_Stdout ("  tokenize   Dump the token stream of a source file");
      Put_Stdout ("  parse      Dump the syntax tree of a source file");
      Put_Stdout
        ("  compile    Lower to .beml, .eml, or .js (+ companion .html)");
      Put_Stdout
        ("  run        Evaluate IR EML and print a complex result");
      Put_Stdout ("");
      Put_Stdout ("Input formats (--input-format / -if):");
      Put_Stdout
        ("  mxeml  Mathematical expression (.mxeml); preprocessor on");
      Put_Stdout
        ("  teml   Nested eml tree text (.teml); preprocessor on");
      Put_Stdout
        ("  eml    Stack IR text (.eml); preprocessor off");
      Put_Stdout
        ("  beml   Packed-bit stack IR (.beml); preprocessor off");
      Put_Stdout ("");
      Put_Stdout ("Common options:");
      Put_Stdout
        ("  --input, -i <file>        Optional input file "
         & "(stdin when omitted)");
      Put_Stdout
        ("  --input-format, -if FMT   Required without -i; "
         & "overrides extension");
      Put_Stdout
        ("  --output, -o <file>       Optional output; stdout if omitted");
      Put_Stdout
        ("  --output-format, -of FMT  Output format "
         & "(depends on command; see help)");
      Put_Stdout
        ("  --var, -v $NAME=EXPR      Preprocessor binding "
         & "(mxeml/teml only; repeatable)");
      Put_Stdout
        ("  --warn, -w MODE           default (default), none, or error");
      Put_Stdout
        ("  --no-color                Plain stderr diagnostics");
      Put_Stdout
        ("  --no-logo                 Suppress the startup banner");
      Put_Stdout ("");
      Put_Stdout ("Examples:");
      Put_Stdout ("  eml help");
      Put_Stdout ("  eml help preproc");
      Put_Stdout ("  eml preproc -i f.mxeml -v '$X=1+2'");
      Put_Stdout ("  eml tokenize -i filename.mxeml");
      Put_Stdout ("  eml parse -i filename.teml");
      Put_Stdout ("  eml compile -i filename.mxeml -o out.beml");
      Put_Stdout ("  eml --no-logo tokenize -if eml < prog.eml");
      Put_Stdout ("");
      Put_Stdout
        ("Exit status: 0 on success, 1 on CLI, I/O, preprocess, lex, "
         & "or parse errors.");
   end Put_General_Help;

   procedure Put_Preproc_Help is
   begin
      Put_Stdout ("eml preproc - substitute $VARNAME in mxeml or teml");
      Put_Stdout ("");
      Put_Stdout ("Usage:");
      Put_Stdout
        ("  eml preproc "
         & Common_Options
         & " [--output-format|-of mxeml|teml]");
      Put_Stdout ("");
      Put_Stdout ("Options:");
      Put_Stdout
        ("  --input, -i <file>          Optional input "
         & "(.mxeml or .teml, or stdin)");
      Put_Stdout
        ("  --input-format, -if FMT     mxeml or teml "
         & "(required without -i)");
      Put_Stdout
        ("  --output, -o <file>         Optional output; "
         & "stdout if omitted");
      Put_Stdout
        ("  --output-format, -of FMT    mxeml or teml; "
         & "default = input format");
      Put_Stdout
        ("  --var, -v $NAME=EXPR        Bind $NAME to EXPRESSION");
      Put_Stdout
        ("  --warn, -w MODE             default, none, or error");
      Put_Stdout ("");
      Put_Stdout ("Output extensions must match --output-format:");
      Put_Stdout ("  mxeml -> .mxeml");
      Put_Stdout ("  teml  -> .teml");
      Put_Stdout ("");
      Put_Stdout ("Examples:");
      Put_Stdout ("  eml preproc -i f.mxeml -v '$X=1+2'");
      Put_Stdout ("  eml preproc -i f.teml -o out.teml");
      Put_Stdout ("  eml --no-logo preproc -if mxeml < in.mxeml");
   end Put_Preproc_Help;

   procedure Put_Tokenize_Help is
   begin
      Put_Stdout ("eml tokenize - dump tokens from mxeml, teml, or eml");
      Put_Stdout ("");
      Put_Stdout ("Usage:");
      Put_Stdout
        ("  eml tokenize "
         & Common_Options
         & " [--output-format|-of tokens]");
      Put_Stdout ("");
      Put_Stdout ("Options:");
      Put_Stdout
        ("  --input, -i <file>          Optional input file or stdin");
      Put_Stdout
        ("  --input-format, -if FMT     mxeml, teml, or eml "
         & "(required without -i)");
      Put_Stdout
        ("  --output, -o <file.tokens>  Optional token dump file");
      Put_Stdout
        ("  --output-format, -of FMT    tokens only (default)");
      Put_Stdout
        ("  --var, -v $NAME=EXPR        Preprocessor binding "
         & "(mxeml/teml only)");
      Put_Stdout ("");
      Put_Stdout ("Examples:");
      Put_Stdout ("  eml tokenize -i filename.mxeml");
      Put_Stdout ("  eml tokenize -i f.eml -o other.tokens");
      Put_Stdout ("  eml tokenize -if teml < in.teml");
   end Put_Tokenize_Help;

   procedure Put_Parse_Help is
   begin
      Put_Stdout ("eml parse - dump the syntax tree from a source file");
      Put_Stdout ("");
      Put_Stdout ("Usage:");
      Put_Stdout
        ("  eml parse "
         & Common_Options
         & " [--output-format|-of mermaid|md|dot|svg]");
      Put_Stdout ("");
      Put_Stdout ("Options:");
      Put_Stdout
        ("  --input, -i <file>          Optional input file or stdin");
      Put_Stdout
        ("  --input-format, -if FMT     mxeml, teml, eml, or beml");
      Put_Stdout
        ("  --output, -o <file>         Optional dump file");
      Put_Stdout
        ("  --output-format, -of FMT    mermaid (default), md, dot, svg");
      Put_Stdout
        ("  --var, -v $NAME=EXPR        Preprocessor binding "
         & "(mxeml/teml only)");
      Put_Stdout ("");
      Put_Stdout ("mxeml input dumps the expression AST; "
                  & "teml/eml/beml dump the IR tree.");
      Put_Stdout ("");
      Put_Stdout ("Output extensions must match the format:");
      Put_Stdout ("  mermaid -> .syntaxtree");
      Put_Stdout ("  md      -> .md");
      Put_Stdout ("  dot     -> .dot");
      Put_Stdout ("  svg     -> .svg");
      Put_Stdout ("");
      Put_Stdout ("Examples:");
      Put_Stdout ("  eml parse -i filename.mxeml");
      Put_Stdout ("  eml parse -i f.teml -of md -o other.md");
      Put_Stdout ("  eml parse -if beml -i prog.beml");
   end Put_Parse_Help;

   procedure Put_Compile_Help is
   begin
      Put_Stdout ("eml compile - lower a source file to EML IR");
      Put_Stdout ("");
      Put_Stdout ("Usage:");
      Put_Stdout
        ("  eml compile "
         & Common_Options
         & " [--output-format|-of eml|beml|js]");
      Put_Stdout ("");
      Put_Stdout ("Options:");
      Put_Stdout
        ("  --input, -i <file>          Optional input file or stdin");
      Put_Stdout
        ("  --input-format, -if FMT     mxeml, teml, eml, or beml");
      Put_Stdout
        ("  --output, -o <file>         Optional output; stdout if omitted");
      Put_Stdout
        ("  --output-format, -of FMT    beml (default), eml, or js");
      Put_Stdout
        ("  --var, -v $NAME=EXPR        Preprocessor binding "
         & "(mxeml/teml only)");
      Put_Stdout ("");
      Put_Stdout ("Output extensions must match --output-format:");
      Put_Stdout ("  beml -> .beml");
      Put_Stdout ("  eml  -> .eml");
      Put_Stdout ("  js   -> .js (writes companion .html beside -o)");
      Put_Stdout ("");
      Put_Stdout
        ("Compiling eml to eml or beml to beml is rejected "
         & "(use conversion instead).");
      Put_Stdout
        ("-of js emits browser JavaScript (math.js) and, "
         & "when -o is set, a companion .html that loads "
         & "the script and shows main().");
      Put_Stdout
        ("Without -o, only the JavaScript goes to stdout "
         & "(no HTML).");
      Put_Stdout ("");
      Put_Stdout ("Examples:");
      Put_Stdout ("  eml compile -i filename.mxeml -o other.beml");
      Put_Stdout ("  eml compile -i f.eml -of beml -o out.beml");
      Put_Stdout ("  eml --no-logo compile -if mxeml < in.mxeml -of eml");
      Put_Stdout ("  eml compile -i f.mxeml -of js -o out.js");
   end Put_Compile_Help;

   procedure Put_Run_Help is
   begin
      Put_Stdout ("eml run - evaluate a program and print a complex result");
      Put_Stdout ("");
      Put_Stdout ("Usage:");
      Put_Stdout ("  eml run " & Run_Options);
      Put_Stdout ("");
      Put_Stdout ("Options:");
      Put_Stdout
        ("  --input, -i <file>          Optional input file or stdin");
      Put_Stdout
        ("  --input-format, -if FMT     mxeml, teml, eml, or beml");
      Put_Stdout
        ("  --var, -v $NAME=EXPR        Preprocessor binding "
         & "(mxeml/teml only)");
      Put_Stdout
        ("  --warn, -w MODE             default, none, or error");
      Put_Stdout ("");
      Put_Stdout
        ("run does not accept --output/-o or --output-format/-of.");
      Put_Stdout
        ("On success, prints one compact complex value on stdout.");
      Put_Stdout ("");
      Put_Stdout ("Examples:");
      Put_Stdout ("  eml run -i filename.mxeml");
      Put_Stdout ("  eml run -i f.teml -v '$X=1'");
      Put_Stdout ("  eml --no-logo run -if eml < prog.eml");
      Put_Stdout ("  eml run -i f.beml");
   end Put_Run_Help;

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

   function Read_Stdin_Text return String is
      Buffer : Unbounded_String;
   begin
      while not Ada.Text_IO.End_Of_File (Ada.Text_IO.Standard_Input) loop
         Append (Buffer, Ada.Text_IO.Get_Line (Ada.Text_IO.Standard_Input));
         if not Ada.Text_IO.End_Of_File (Ada.Text_IO.Standard_Input) then
            Append (Buffer, ASCII.LF);
         end if;
      end loop;
      return To_String (Buffer);
   end Read_Stdin_Text;

   function Read_Binary_File (Path : String)
      return Ada.Streams.Stream_Element_Array is
      File   : Ada.Streams.Stream_IO.File_Type;
      Buffer : Ada.Streams.Stream_Element_Array (1 .. 1_000_000);
      Last   : Ada.Streams.Stream_Element_Offset;
   begin
      Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, Path);
      Ada.Streams.Stream_IO.Read (File, Buffer, Last);
      Ada.Streams.Stream_IO.Close (File);
      return Buffer (1 .. Last);
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (File) then
            Ada.Streams.Stream_IO.Close (File);
         end if;
         raise;
   end Read_Binary_File;

   function Read_Stdin_Binary return Ada.Streams.Stream_Element_Array is
      File   : Ada.Streams.Stream_IO.File_Type;
      Buffer : Ada.Streams.Stream_Element_Array (1 .. 1_000_000);
      Last   : Ada.Streams.Stream_Element_Offset;
   begin
      Ada.Streams.Stream_IO.Open
        (File, Ada.Streams.Stream_IO.In_File, "/dev/stdin");
      Ada.Streams.Stream_IO.Read (File, Buffer, Last);
      Ada.Streams.Stream_IO.Close (File);
      return Buffer (1 .. Last);
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (File) then
            Ada.Streams.Stream_IO.Close (File);
         end if;
         raise;
   end Read_Stdin_Binary;

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

   function To_Teml_Origins
     (Origins : Expr_Tokenizer.Origin_Map_Access)
      return Teml_Tokenizer.Origin_Map_Access
   is
   begin
      if Origins = null then
         return null;
      end if;
      declare
         Result : constant Teml_Tokenizer.Origin_Map_Access :=
           new Teml_Tokenizer.Origin_Map'(Origins'Range => <>);
      begin
         for I in Origins'Range loop
            Result (I).Line := Origins (I).Line;
            Result (I).Column := Origins (I).Column;
            Result (I).From_Var := Origins (I).From_Var;
            Result (I).Var_Name := Origins (I).Var_Name;
         end loop;
         return Result;
      end;
   end To_Teml_Origins;

   function Input_Format_Image (Fmt : Input_Format) return String is
   begin
      case Fmt is
         when Mxeml     => return "mxeml";
         when Teml      => return "teml";
         when Stack_Eml => return "eml";
         when Beml      => return "beml";
      end case;
   end Input_Format_Image;

   function Input_Extension (Fmt : Input_Format) return String is
   begin
      case Fmt is
         when Mxeml     => return ".mxeml";
         when Teml      => return ".teml";
         when Stack_Eml => return ".eml";
         when Beml      => return ".beml";
      end case;
   end Input_Extension;

   function Allowed_Extensions (Cmd : String) return String is
   begin
      if Cmd = "preproc" then
         return ".mxeml or .teml";
      elsif Cmd = "tokenize" then
         return ".mxeml, .teml, or .eml";
      else
         return ".mxeml, .teml, .eml, or .beml";
      end if;
   end Allowed_Extensions;

   function Parse_Input_Format
     (S : String; Ok : out Boolean) return Input_Format
   is
   begin
      Ok := True;
      if S = "mxeml" then
         return Mxeml;
      elsif S = "teml" then
         return Teml;
      elsif S = "eml" then
         return Stack_Eml;
      elsif S = "beml" then
         return Beml;
      else
         Ok := False;
         return Mxeml;
      end if;
   end Parse_Input_Format;

   function Detect_Input_Format
     (Path : String; Ok : out Boolean) return Input_Format
   is
   begin
      if Ends_With (Path, ".mxeml") then
         Ok := True;
         return Mxeml;
      elsif Ends_With (Path, ".teml") then
         Ok := True;
         return Teml;
      elsif Ends_With (Path, ".eml") then
         Ok := True;
         return Stack_Eml;
      elsif Ends_With (Path, ".beml") then
         Ok := True;
         return Beml;
      else
         Ok := False;
         return Mxeml;
      end if;
   end Detect_Input_Format;

   function Input_Format_Allowed
     (Cmd : String; Fmt : Input_Format) return Boolean
   is
   begin
      if Cmd = "preproc" then
         return Fmt in Mxeml | Teml;
      elsif Cmd = "tokenize" then
         return Fmt /= Beml;
      else
         return True;
      end if;
   end Input_Format_Allowed;

   function Uses_Preprocessor (Fmt : Input_Format) return Boolean is
     (Fmt in Mxeml | Teml);

   function Parse_Tree_Format
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
   end Parse_Tree_Format;

   function Tree_Extension (Fmt : Expr_Parser.Output_Format) return String is
   begin
      case Fmt is
         when Expr_Parser.Mermaid  => return ".syntaxtree";
         when Expr_Parser.Markdown => return ".md";
         when Expr_Parser.Dot      => return ".dot";
         when Expr_Parser.Svg      => return ".svg";
      end case;
   end Tree_Extension;

   function To_IR_Tree_Format
     (Fmt : Expr_Parser.Output_Format) return IR_Eml.Tree_Output_Format
   is
   begin
      case Fmt is
         when Expr_Parser.Mermaid  => return IR_Eml.Mermaid;
         when Expr_Parser.Markdown => return IR_Eml.Markdown;
         when Expr_Parser.Dot      => return IR_Eml.Dot;
         when Expr_Parser.Svg      => return IR_Eml.Svg;
      end case;
   end To_IR_Tree_Format;

   function Parse_Compile_Output_Format
     (S : String; Ok : out Boolean) return Compile_Output_Format
   is
   begin
      Ok := True;
      if S = "eml" then
         return Eml_Text;
      elsif S = "beml" then
         return Beml_Binary;
      elsif S = "js" then
         return Javascript;
      else
         Ok := False;
         return Beml_Binary;
      end if;
   end Parse_Compile_Output_Format;

   function Compile_Extension (Fmt : Compile_Output_Format) return String is
   begin
      case Fmt is
         when Eml_Text    => return ".eml";
         when Beml_Binary => return ".beml";
         when Javascript  => return ".js";
      end case;
   end Compile_Extension;

   function Compile_Format_Image (Fmt : Compile_Output_Format) return String is
   begin
      case Fmt is
         when Eml_Text    => return "eml";
         when Beml_Binary => return "beml";
         when Javascript  => return "js";
      end case;
   end Compile_Format_Image;

   function Parse_Preproc_Output_Format
     (S : String; Ok : out Boolean) return Input_Format
   is
   begin
      Ok := True;
      if S = "mxeml" then
         return Mxeml;
      elsif S = "teml" then
         return Teml;
      else
         Ok := False;
         return Mxeml;
      end if;
   end Parse_Preproc_Output_Format;

   procedure Emit_Expr_Lex_Diagnostics
     (Diags     : Expr_Tokenizer.Diagnostic_Array_Access;
      Use_Color : Boolean)
   is
   begin
      if Diags /= null then
         for D of Diags.all loop
            Emit_Error_Line
              (Format_Line_With_Suffix
                 (D.Id,
                  Natural (D.Line),
                  Natural (D.Column),
                  To_String (D.Param1),
                  "",
                  Var_Suffix (D.From_Var, D.Var_Name)),
               Use_Color);
         end loop;
      end if;
   end Emit_Expr_Lex_Diagnostics;

   procedure Emit_Teml_Lex_Diagnostics
     (Diags     : Teml_Tokenizer.Diagnostic_Array_Access;
      Use_Color : Boolean)
   is
   begin
      if Diags /= null then
         for D of Diags.all loop
            Emit_Error_Line
              (Format_Line_With_Suffix
                 (D.Id,
                  Natural (D.Line),
                  Natural (D.Column),
                  To_String (D.Param1),
                  "",
                  Var_Suffix (D.From_Var, D.Var_Name)),
               Use_Color);
         end loop;
      end if;
   end Emit_Teml_Lex_Diagnostics;

   procedure Emit_Eml_Lex_Diagnostics
     (Diags     : Eml_Tokenizer.Diagnostic_Array_Access;
      Use_Color : Boolean)
   is
   begin
      if Diags /= null then
         for D of Diags.all loop
            Emit_Error_Line
              (Format_Line
                 (D.Id,
                  Natural (D.Line),
                  Natural (D.Column),
                  To_String (D.Param1)),
               Use_Color);
         end loop;
      end if;
   end Emit_Eml_Lex_Diagnostics;

   procedure Emit_Expr_Parse_Error
     (R : Expr_Parser.Parse_Result; Use_Color : Boolean)
   is
   begin
      Emit_Error_Line
        (Format_Line_With_Suffix
           (R.Error_Id,
            Natural (R.Error_Line),
            Natural (R.Error_Col),
            To_String (R.Param1),
            "",
            Var_Suffix (R.From_Var, R.Var_Name)),
         Use_Color);
   end Emit_Expr_Parse_Error;

   procedure Emit_Teml_Parse_Error
     (R : Teml_Parser.Parse_Result; Use_Color : Boolean)
   is
   begin
      Emit_Error_Line
        (Format_Line_With_Suffix
           (R.Error_Id,
            Natural (R.Error_Line),
            Natural (R.Error_Col),
            To_String (R.Param1),
            "",
            Var_Suffix (R.From_Var, R.Var_Name)),
         Use_Color);
   end Emit_Teml_Parse_Error;

   procedure Emit_Eml_Parse_Error
     (R : Eml_Parser.Parse_Result; Use_Color : Boolean)
   is
   begin
      Emit_Error_Line
        (Format_Line
           (R.Error_Id,
            Natural (R.Error_Line),
            Natural (R.Error_Col),
            To_String (R.Param1)),
         Use_Color);
   end Emit_Eml_Parse_Error;

   procedure Emit_Beml_Read_Error
     (R : Beml_Reader.Read_Result; Use_Color : Boolean)
   is
   begin
      Emit_Error_Line
        (Format_Line
           (R.Error_Id,
            Natural (R.Error_Line),
            Natural (R.Error_Col)),
         Use_Color);
   end Emit_Beml_Read_Error;

   procedure Emit_Beml_Parse_Error
     (R : Beml_Parser.Parse_Result; Use_Color : Boolean)
   is
   begin
      Emit_Error_Line
        (Format_Line
           (R.Error_Id,
            Natural (R.Error_Line),
            Natural (R.Error_Col)),
         Use_Color);
   end Emit_Beml_Parse_Error;

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
            Emit_Error_Line
              (Format_Line
                 (PP_Unbound_Variable,
                  Natural (D.Line),
                  Natural (D.Column),
                  To_String (D.Var_Name)),
               Use_Color);
         end loop;
      end if;

      if Prep.Unused /= null then
         for Name of Prep.Unused.all loop
            case Warn is
               when Default_Warn =>
                  Emit_Warning_Line
                    (Format_Line
                       (PP_Unused_Variable_Warn, 0, 0, To_String (Name)),
                     Use_Color);
               when No_Warn =>
                  null;
               when Error_Warn =>
                  Emit_Error_Line
                    (Format_Line
                       (PP_Unused_Variable_Error, 0, 0, To_String (Name)),
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

   function Check_Unused_Bindings
     (Bindings  : Binding_Array;
      Warn      : Warn_Mode;
      Use_Color : Boolean) return Ada.Command_Line.Exit_Status
   is
      Unused_Error : Boolean := False;
   begin
      for B of Bindings loop
         case Warn is
            when Default_Warn =>
               Emit_Warning_Line
                 (Format_Line
                    (PP_Unused_Variable_Warn, 0, 0, To_String (B.Name)),
                  Use_Color);
            when No_Warn =>
               null;
            when Error_Warn =>
               Emit_Error_Line
                 (Format_Line
                    (PP_Unused_Variable_Error, 0, 0, To_String (B.Name)),
                  Use_Color);
               Unused_Error := True;
         end case;
      end loop;
      if Unused_Error then
         return Ada.Command_Line.Failure;
      end if;
      return Ada.Command_Line.Success;
   end Check_Unused_Bindings;

   function Run_Preproc
     (Source      : String;
      Output_Path : String;
      Has_Output  : Boolean;
      Bindings    : Binding_Array;
      Warn        : Warn_Mode;
      Use_Color   : Boolean)
      return Ada.Command_Line.Exit_Status
   is
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

   function Run_Tokenize_Mxeml
     (Source      : String;
      Output_Path : String;
      Has_Output  : Boolean;
      Bindings    : Binding_Array;
      Warn        : Warn_Mode;
      Use_Color   : Boolean)
      return Ada.Command_Line.Exit_Status
   is
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

      if Result.Had_Errors then
         Emit_Expr_Lex_Diagnostics (Result.Diagnostics, Use_Color);
         return Ada.Command_Line.Failure;
      end if;
      return Ada.Command_Line.Success;
   end Run_Tokenize_Mxeml;

   function Run_Tokenize_Teml
     (Source      : String;
      Output_Path : String;
      Has_Output  : Boolean;
      Bindings    : Binding_Array;
      Warn        : Warn_Mode;
      Use_Color   : Boolean)
      return Ada.Command_Line.Exit_Status
   is
      Prep   : Expr_Preprocessor.Preprocess_Result;
      Status : Ada.Command_Line.Exit_Status;
      Result : Teml_Tokenizer.Tokenize_Result;
   begin
      Status := Preprocess_And_Check (Source, Bindings, Warn, Use_Color, Prep);
      if Status /= Ada.Command_Line.Success then
         return Status;
      end if;

      Result :=
        Teml_Tokenizer.Tokenize
          (To_String (Prep.Text), To_Teml_Origins (Prep.Origins));

      if Has_Output then
         declare
            File : Ada.Text_IO.File_Type;
         begin
            Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Output_Path);
            Teml_Tokenizer.Write_Dump (Result.Tokens.all, File);
            Ada.Text_IO.Close (File);
         end;
      else
         Teml_Tokenizer.Write_Dump_To_Stdout (Result.Tokens.all);
      end if;

      if Result.Had_Errors then
         Emit_Teml_Lex_Diagnostics (Result.Diagnostics, Use_Color);
         return Ada.Command_Line.Failure;
      end if;
      return Ada.Command_Line.Success;
   end Run_Tokenize_Teml;

   function Run_Tokenize_Eml
     (Source      : String;
      Output_Path : String;
      Has_Output  : Boolean;
      Use_Color   : Boolean)
      return Ada.Command_Line.Exit_Status
   is
      Result : Eml_Tokenizer.Tokenize_Result;
   begin
      Result := Eml_Tokenizer.Tokenize (Source);

      if Has_Output then
         declare
            File : Ada.Text_IO.File_Type;
         begin
            Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Output_Path);
            Eml_Tokenizer.Write_Dump (Result.Tokens.all, File);
            Ada.Text_IO.Close (File);
         end;
      else
         Eml_Tokenizer.Write_Dump_To_Stdout (Result.Tokens.all);
      end if;

      if Result.Had_Errors then
         Emit_Eml_Lex_Diagnostics (Result.Diagnostics, Use_Color);
         return Ada.Command_Line.Failure;
      end if;
      return Ada.Command_Line.Success;
   end Run_Tokenize_Eml;

   function Run_Parse_Mxeml
     (Source      : String;
      Output_Path : String;
      Has_Output  : Boolean;
      Fmt         : Expr_Parser.Output_Format;
      Bindings    : Binding_Array;
      Warn        : Warn_Mode;
      Use_Color   : Boolean)
      return Ada.Command_Line.Exit_Status
   is
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
         Emit_Expr_Lex_Diagnostics (Tok.Diagnostics, Use_Color);
         return Ada.Command_Line.Failure;
      end if;

      declare
         Parsed : constant Expr_Parser.Parse_Result :=
           Expr_Parser.Parse (Tok.Tokens.all);
      begin
         if Parsed.Had_Error then
            Emit_Expr_Parse_Error (Parsed, Use_Color);
            return Ada.Command_Line.Failure;
         end if;

         if Has_Output then
            Expr_Parser.Write_To_File (Parsed.Root, Fmt, Output_Path);
         else
            Expr_Parser.Write_To_Stdout (Parsed.Root, Fmt);
         end if;
         return Ada.Command_Line.Success;
      end;
   end Run_Parse_Mxeml;

   function Run_Parse_IR
     (Root        : IR_Eml.Node_Access;
      Output_Path : String;
      Has_Output  : Boolean;
      Fmt         : Expr_Parser.Output_Format)
      return Ada.Command_Line.Exit_Status
   is
      IR_Fmt : constant IR_Eml.Tree_Output_Format := To_IR_Tree_Format (Fmt);
   begin
      if Has_Output then
         IR_Eml.Write_Tree_To_File (Root, IR_Fmt, Output_Path);
      else
         IR_Eml.Write_Tree_To_Stdout (Root, IR_Fmt);
      end if;
      return Ada.Command_Line.Success;
   end Run_Parse_IR;

   function Run_Parse_Teml
     (Source      : String;
      Output_Path : String;
      Has_Output  : Boolean;
      Fmt         : Expr_Parser.Output_Format;
      Bindings    : Binding_Array;
      Warn        : Warn_Mode;
      Use_Color   : Boolean)
      return Ada.Command_Line.Exit_Status
   is
      Prep   : Expr_Preprocessor.Preprocess_Result;
      Status : Ada.Command_Line.Exit_Status;
      Tok    : Teml_Tokenizer.Tokenize_Result;
   begin
      Status := Preprocess_And_Check (Source, Bindings, Warn, Use_Color, Prep);
      if Status /= Ada.Command_Line.Success then
         return Status;
      end if;

      Tok :=
        Teml_Tokenizer.Tokenize
          (To_String (Prep.Text), To_Teml_Origins (Prep.Origins));

      if Tok.Had_Errors then
         Emit_Teml_Lex_Diagnostics (Tok.Diagnostics, Use_Color);
         return Ada.Command_Line.Failure;
      end if;

      declare
         Parsed : constant Teml_Parser.Parse_Result :=
           Teml_Parser.Parse (Tok.Tokens.all);
      begin
         if Parsed.Had_Error then
            Emit_Teml_Parse_Error (Parsed, Use_Color);
            return Ada.Command_Line.Failure;
         end if;

         return Run_Parse_IR (Parsed.Root, Output_Path, Has_Output, Fmt);
      end;
   end Run_Parse_Teml;

   function Run_Parse_Eml
     (Source      : String;
      Output_Path : String;
      Has_Output  : Boolean;
      Fmt         : Expr_Parser.Output_Format;
      Use_Color   : Boolean)
      return Ada.Command_Line.Exit_Status
   is
      Tok : Eml_Tokenizer.Tokenize_Result;
   begin
      Tok := Eml_Tokenizer.Tokenize (Source);

      if Tok.Had_Errors then
         Emit_Eml_Lex_Diagnostics (Tok.Diagnostics, Use_Color);
         return Ada.Command_Line.Failure;
      end if;

      declare
         Parsed : constant Eml_Parser.Parse_Result :=
           Eml_Parser.Parse (Tok.Tokens.all);
      begin
         if Parsed.Had_Error then
            Emit_Eml_Parse_Error (Parsed, Use_Color);
            return Ada.Command_Line.Failure;
         end if;

         return Run_Parse_IR (Parsed.Root, Output_Path, Has_Output, Fmt);
      end;
   end Run_Parse_Eml;

   function Run_Parse_Beml
     (Data        : Ada.Streams.Stream_Element_Array;
      Output_Path : String;
      Has_Output  : Boolean;
      Fmt         : Expr_Parser.Output_Format;
      Use_Color   : Boolean)
      return Ada.Command_Line.Exit_Status
   is
      Read_R : constant Beml_Reader.Read_Result :=
        Beml_Reader.Read_Bytes (Data);
   begin
      if Read_R.Had_Error then
         Emit_Beml_Read_Error (Read_R, Use_Color);
         return Ada.Command_Line.Failure;
      end if;

      declare
         Parsed : constant Beml_Parser.Parse_Result :=
           Beml_Parser.Parse (Read_R.Opcodes);
      begin
         if Parsed.Had_Error then
            Emit_Beml_Parse_Error (Parsed, Use_Color);
            return Ada.Command_Line.Failure;
         end if;

         return Run_Parse_IR (Parsed.Root, Output_Path, Has_Output, Fmt);
      end;
   end Run_Parse_Beml;

   procedure Write_Compile_Output
     (IR          : IR_Eml.Node_Access;
      Meta        : IR_Eml.Dump_Meta;
      Output_Path : String;
      Has_Output  : Boolean;
      Fmt         : Compile_Output_Format)
   is
   begin
      case Fmt is
         when Eml_Text =>
            if Has_Output then
               IR_Eml.Write_Eml_To_File (IR, Meta, Output_Path);
            else
               IR_Eml.Write_Eml_To_Stdout (IR, Meta);
            end if;
         when Beml_Binary =>
            if Has_Output then
               IR_Eml.Write_Beml_To_File (IR, Meta, Output_Path);
            else
               IR_Eml.Write_Beml_To_Stdout (IR, Meta);
            end if;
         when Javascript =>
            if Has_Output then
               Js_Backend.Write_Js_To_File (IR, Meta, Output_Path);
               Js_Backend.Write_Html_To_File (Output_Path);
            else
               Js_Backend.Write_Js_To_Stdout (IR, Meta);
            end if;
      end case;
   end Write_Compile_Output;

   function Load_IR
     (In_Fmt    : Input_Format;
      Source    : String;
      Bin_Data  : Ada.Streams.Stream_Element_Array;
      Bindings  : Binding_Array;
      Warn      : Warn_Mode;
      Use_Color : Boolean;
      Root      : out IR_Eml.Node_Access)
      return Ada.Command_Line.Exit_Status
   is
   begin
      Root := null;
      case In_Fmt is
         when Mxeml =>
            declare
               Prep   : Expr_Preprocessor.Preprocess_Result;
               Status : Ada.Command_Line.Exit_Status;
               Tok    : Expr_Tokenizer.Tokenize_Result;
            begin
               Status :=
                 Preprocess_And_Check
                   (Source, Bindings, Warn, Use_Color, Prep);
               if Status /= Ada.Command_Line.Success then
                  return Status;
               end if;

               Tok :=
                 Expr_Tokenizer.Tokenize
                   (To_String (Prep.Text), Prep.Origins);

               if Tok.Had_Errors then
                  Emit_Expr_Lex_Diagnostics (Tok.Diagnostics, Use_Color);
                  return Ada.Command_Line.Failure;
               end if;

               declare
                  Parsed : constant Expr_Parser.Parse_Result :=
                    Expr_Parser.Parse (Tok.Tokens.all);
               begin
                  if Parsed.Had_Error then
                     Emit_Expr_Parse_Error (Parsed, Use_Color);
                     return Ada.Command_Line.Failure;
                  end if;

                  Root := Expr_Lower.Lower (Parsed.Root);
                  return Ada.Command_Line.Success;
               end;
            end;

         when Teml =>
            declare
               Prep   : Expr_Preprocessor.Preprocess_Result;
               Status : Ada.Command_Line.Exit_Status;
               Tok    : Teml_Tokenizer.Tokenize_Result;
            begin
               Status :=
                 Preprocess_And_Check
                   (Source, Bindings, Warn, Use_Color, Prep);
               if Status /= Ada.Command_Line.Success then
                  return Status;
               end if;

               Tok :=
                 Teml_Tokenizer.Tokenize
                   (To_String (Prep.Text), To_Teml_Origins (Prep.Origins));

               if Tok.Had_Errors then
                  Emit_Teml_Lex_Diagnostics (Tok.Diagnostics, Use_Color);
                  return Ada.Command_Line.Failure;
               end if;

               declare
                  Parsed : constant Teml_Parser.Parse_Result :=
                    Teml_Parser.Parse (Tok.Tokens.all);
               begin
                  if Parsed.Had_Error then
                     Emit_Teml_Parse_Error (Parsed, Use_Color);
                     return Ada.Command_Line.Failure;
                  end if;

                  Root := Parsed.Root;
                  return Ada.Command_Line.Success;
               end;
            end;

         when Stack_Eml =>
            declare
               Tok : Eml_Tokenizer.Tokenize_Result;
            begin
               Tok := Eml_Tokenizer.Tokenize (Source);

               if Tok.Had_Errors then
                  Emit_Eml_Lex_Diagnostics (Tok.Diagnostics, Use_Color);
                  return Ada.Command_Line.Failure;
               end if;

               declare
                  Parsed : constant Eml_Parser.Parse_Result :=
                    Eml_Parser.Parse (Tok.Tokens.all);
               begin
                  if Parsed.Had_Error then
                     Emit_Eml_Parse_Error (Parsed, Use_Color);
                     return Ada.Command_Line.Failure;
                  end if;

                  Root := Parsed.Root;
                  return Ada.Command_Line.Success;
               end;
            end;

         when Beml =>
            declare
               Read_R : constant Beml_Reader.Read_Result :=
                 Beml_Reader.Read_Bytes (Bin_Data);
            begin
               if Read_R.Had_Error then
                  Emit_Beml_Read_Error (Read_R, Use_Color);
                  return Ada.Command_Line.Failure;
               end if;

               declare
                  Parsed : constant Beml_Parser.Parse_Result :=
                    Beml_Parser.Parse (Read_R.Opcodes);
               begin
                  if Parsed.Had_Error then
                     Emit_Beml_Parse_Error (Parsed, Use_Color);
                     return Ada.Command_Line.Failure;
                  end if;

                  Root := Parsed.Root;
                  return Ada.Command_Line.Success;
               end;
            end;
      end case;
   end Load_IR;

   function Run_Emlir
     (Source_Label : String;
      In_Fmt       : Input_Format;
      Source       : String;
      Bin_Data     : Ada.Streams.Stream_Element_Array;
      Output_Path  : String;
      Has_Output   : Boolean;
      Fmt          : Compile_Output_Format;
      Bindings     : Binding_Array;
      Warn         : Warn_Mode;
      Use_Color    : Boolean) return Ada.Command_Line.Exit_Status
   is
      Meta : constant IR_Eml.Dump_Meta :=
        (Source_Path => To_Unbounded_String (Source_Label),
         Version     => To_Unbounded_String (Info.Version),
         Compiled_At => Ada.Calendar.Clock);
      Root   : IR_Eml.Node_Access;
      Status : Ada.Command_Line.Exit_Status;
   begin
      Status :=
        Load_IR (In_Fmt, Source, Bin_Data, Bindings, Warn, Use_Color, Root);
      if Status /= Ada.Command_Line.Success then
         return Status;
      end if;
      Write_Compile_Output (Root, Meta, Output_Path, Has_Output, Fmt);
      return Ada.Command_Line.Success;
   end Run_Emlir;

   function Run_Interpret
     (In_Fmt    : Input_Format;
      Source    : String;
      Bin_Data  : Ada.Streams.Stream_Element_Array;
      Bindings  : Binding_Array;
      Warn      : Warn_Mode;
      Use_Color : Boolean) return Ada.Command_Line.Exit_Status
   is
      Root   : IR_Eml.Node_Access;
      Status : Ada.Command_Line.Exit_Status;
      Eval   : Interpreter.Eval_Result;
      Line   : Natural;
      Col    : Natural;
      Id     : Diagnostic_Id;
   begin
      Status :=
        Load_IR (In_Fmt, Source, Bin_Data, Bindings, Warn, Use_Color, Root);
      if Status /= Ada.Command_Line.Success then
         return Status;
      end if;

      Eval := Interpreter.Evaluate (Root);
      if Eval.Status = Interpreter.Ok then
         Put_Stdout (Interpreter.Format_Complex (Eval.Value));
         return Ada.Command_Line.Success;
      end if;

      case Eval.Status is
         when Interpreter.Stack_Underflow =>
            Id := RT_Stack_Underflow;
         when Interpreter.Stack_Not_Single =>
            Id := RT_Stack_Not_Single;
         when Interpreter.Eval_Numeric_Error =>
            Id := RT_Numeric_Error;
         when Interpreter.Ok =>
            Id := RT_Numeric_Error;
      end case;

      if Eval.Index = 0 then
         Line := 0;
         Col := 0;
      else
         Line := 1;
         Col := Eval.Index;
      end if;

      Emit_Error_Line (Format_Line (Id, Line, Col), Use_Color);
      return Ada.Command_Line.Failure;
   end Run_Interpret;

   function Run_Internal
     (Args               : Arg_Array;
      Injected_Text      : String;
      Have_Injected_Text : Boolean;
      Injected_Bin       : Ada.Streams.Stream_Element_Array;
      Have_Injected_Bin  : Boolean)
      return Ada.Command_Line.Exit_Status
   is
      No_Color           : Boolean := False;
      No_Logo            : Boolean := False;
      Subcommand         : Unbounded_String;
      Topic              : Unbounded_String;
      Input_Path         : Unbounded_String;
      Output_Path        : Unbounded_String;
      Output_Format_Text : Unbounded_String;
      Input_Format_Text  : Unbounded_String;
      Warn_Text          : Unbounded_String := To_Unbounded_String ("default");
      Bindings           : Binding_List (1 .. 64);
      Binding_Count      : Natural := 0;
      Have_Input         : Boolean := False;
      Have_Output        : Boolean := False;
      Have_Output_Format : Boolean := False;
      Have_Input_Format  : Boolean := False;
      Have_Warn          : Boolean := False;
      Have_Sub           : Boolean := False;
      Have_Topic         : Boolean := False;
      I                  : Positive := 1;
      Use_Color          : Boolean;
      Cmd                : Unbounded_String;
      Tree_Fmt           : Expr_Parser.Output_Format := Expr_Parser.Mermaid;
      Compile_Fmt        : Compile_Output_Format := Beml_Binary;
      Preproc_Out_Fmt    : Input_Format := Mxeml;
      Format_Ok          : Boolean;
      Compile_Ok         : Boolean;
      Preproc_Ok         : Boolean;
      Input_Ok           : Boolean;
      Warn_Ok            : Boolean;
      Warn               : Warn_Mode := Default_Warn;
      Var_Ok             : Boolean;
      Binding            : Expr_Preprocessor.Binding;
      In_Fmt             : Input_Format := Mxeml;
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
                    (CLI_Missing_Command_With_Arg, not No_Color, A);
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
                  Fail_CLI (CLI_Unexpected_Argument, not No_Color, A);
                  return Ada.Command_Line.Failure;
               end if;
               if Have_Topic then
                  if not No_Logo then
                     Put_Banner;
                  end if;
                  Fail_CLI (CLI_Unexpected_Argument, not No_Color, A);
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
                  Fail_CLI (CLI_Repeated_Input, not No_Color);
                  return Ada.Command_Line.Failure;
               end if;
               if I = Args'Last then
                  if not No_Logo then
                     Put_Banner;
                  end if;
                  Fail_CLI (CLI_Missing_Flag_Value, not No_Color, A);
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
                  Fail_CLI (CLI_Repeated_Output, not No_Color);
                  return Ada.Command_Line.Failure;
               end if;
               if I = Args'Last then
                  if not No_Logo then
                     Put_Banner;
                  end if;
                  Fail_CLI (CLI_Missing_Flag_Value, not No_Color, A);
                  return Ada.Command_Line.Failure;
               end if;
               Output_Path := Args (I + 1);
               Have_Output := True;
               I := I + 2;
            elsif A = "--output-format" or else A = "-of" then
               if Have_Output_Format then
                  if not No_Logo then
                     Put_Banner;
                  end if;
                  Fail_CLI (CLI_Repeated_Output_Format, not No_Color);
                  return Ada.Command_Line.Failure;
               end if;
               if I = Args'Last then
                  if not No_Logo then
                     Put_Banner;
                  end if;
                  Fail_CLI (CLI_Missing_Flag_Value, not No_Color, A);
                  return Ada.Command_Line.Failure;
               end if;
               Output_Format_Text := Args (I + 1);
               Have_Output_Format := True;
               I := I + 2;
            elsif A = "--input-format" or else A = "-if" then
               if Have_Input_Format then
                  if not No_Logo then
                     Put_Banner;
                  end if;
                  Fail_CLI (CLI_Repeated_Input_Format, not No_Color);
                  return Ada.Command_Line.Failure;
               end if;
               if I = Args'Last then
                  if not No_Logo then
                     Put_Banner;
                  end if;
                  Fail_CLI (CLI_Missing_Flag_Value, not No_Color, A);
                  return Ada.Command_Line.Failure;
               end if;
               Input_Format_Text := Args (I + 1);
               Have_Input_Format := True;
               I := I + 2;
            elsif A = "--format" or else A = "-f" then
               if not No_Logo then
                  Put_Banner;
               end if;
               Fail_CLI (CLI_Unexpected_Format_Flag, not No_Color);
               return Ada.Command_Line.Failure;
            elsif A = "--var" or else A = "-v" then
               if I = Args'Last then
                  if not No_Logo then
                     Put_Banner;
                  end if;
                  Fail_CLI (CLI_Missing_Flag_Value, not No_Color, A);
                  return Ada.Command_Line.Failure;
               end if;
               Binding := Parse_Var_Binding (To_String (Args (I + 1)), Var_Ok);
               if not Var_Ok then
                  if not No_Logo then
                     Put_Banner;
                  end if;
                  Fail_CLI
                    (CLI_Invalid_Var_Binding,
                     not No_Color,
                     To_String (Args (I + 1)));
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
                    (CLI_Repeated_Var,
                     not No_Color,
                     To_String (Binding.Name));
                  return Ada.Command_Line.Failure;
               end if;
               if Binding_Count = Bindings'Length then
                  if not No_Logo then
                     Put_Banner;
                  end if;
                  Fail_CLI (CLI_Too_Many_Vars, not No_Color);
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
                  Fail_CLI (CLI_Repeated_Warn, not No_Color);
                  return Ada.Command_Line.Failure;
               end if;
               if I = Args'Last then
                  if not No_Logo then
                     Put_Banner;
                  end if;
                  Fail_CLI (CLI_Missing_Flag_Value, not No_Color, A);
                  return Ada.Command_Line.Failure;
               end if;
               Warn_Text := Args (I + 1);
               Have_Warn := True;
               I := I + 2;
            else
               if not No_Logo then
                  Put_Banner;
               end if;
               Fail_CLI (CLI_Unexpected_Argument, not No_Color, A);
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
         Fail_CLI (CLI_Missing_Command, Use_Color);
         return Ada.Command_Line.Failure;
      end if;

      if not Warn_Ok then
         Fail_CLI
           (CLI_Unknown_Warn_Mode, Use_Color, To_String (Warn_Text));
         return Ada.Command_Line.Failure;
      end if;

      if To_String (Cmd) = "help" then
         if Have_Input
           or else Have_Input_Format
           or else Have_Output
           or else Have_Output_Format
           or else Binding_Count > 0
           or else Have_Warn
         then
            Fail_CLI (CLI_Unexpected_Argument, Use_Color, "--input");
            return Ada.Command_Line.Failure;
         end if;

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
         elsif To_String (Topic) = "run" then
            Put_Run_Help;
            return Ada.Command_Line.Success;
         else
            Fail_CLI
              (CLI_Unknown_Help_Topic, Use_Color, To_String (Topic));
            return Ada.Command_Line.Failure;
         end if;
      end if;

      if To_String (Cmd) /= "preproc"
        and then To_String (Cmd) /= "tokenize"
        and then To_String (Cmd) /= "parse"
        and then To_String (Cmd) /= "compile"
        and then To_String (Cmd) /= "run"
      then
         Fail_CLI (CLI_Unknown_Command, Use_Color, To_String (Cmd));
         return Ada.Command_Line.Failure;
      end if;

      if Have_Input_Format then
         In_Fmt :=
           Parse_Input_Format (To_String (Input_Format_Text), Input_Ok);
         if not Input_Ok then
            Fail_CLI
              (CLI_Unknown_Input_Format,
               Use_Color,
               To_String (Input_Format_Text));
            return Ada.Command_Line.Failure;
         end if;
      elsif Have_Input then
         In_Fmt := Detect_Input_Format (To_String (Input_Path), Input_Ok);
         if not Input_Ok then
            Fail_CLI
              (CLI_Unknown_Extension,
               Use_Color,
               To_String (Input_Path),
               Allowed_Extensions (To_String (Cmd)));
            return Ada.Command_Line.Failure;
         end if;
      else
         Fail_CLI (CLI_Input_Format_Required, Use_Color);
         return Ada.Command_Line.Failure;
      end if;

      if not Input_Format_Allowed (To_String (Cmd), In_Fmt) then
         Fail_CLI
           (CLI_Format_Not_Allowed,
            Use_Color,
            To_String (Cmd),
            Input_Format_Image (In_Fmt));
         return Ada.Command_Line.Failure;
      end if;

      declare
         Source_Label : constant String :=
           (if Have_Input then To_String (Input_Path) else "<stdin>");
         Binds : constant Binding_Array :=
           To_Binding_Array (Bindings, Binding_Count);
      begin
         if not Uses_Preprocessor (In_Fmt) and then Binding_Count > 0 then
            declare
               Status : constant Ada.Command_Line.Exit_Status :=
                 Check_Unused_Bindings (Binds, Warn, Use_Color);
            begin
               if Status /= Ada.Command_Line.Success then
                  return Status;
               end if;
            end;
         end if;

         if To_String (Cmd) = "preproc" then
            if Have_Output_Format then
               Preproc_Out_Fmt :=
                 Parse_Preproc_Output_Format
                   (To_String (Output_Format_Text), Preproc_Ok);
               if not Preproc_Ok then
                  Fail_CLI
                    (CLI_Unknown_Output_Format,
                     Use_Color,
                     To_String (Output_Format_Text),
                     "preproc");
                  return Ada.Command_Line.Failure;
               end if;
               if Preproc_Out_Fmt /= In_Fmt then
                  Fail_CLI
                    (CLI_Preproc_Output_Mismatch,
                     Use_Color,
                     Input_Format_Image (Preproc_Out_Fmt),
                     Input_Format_Image (In_Fmt));
                  return Ada.Command_Line.Failure;
               end if;
            else
               Preproc_Out_Fmt := In_Fmt;
            end if;

            if Have_Output
              and then not Ends_With
                (To_String (Output_Path), Input_Extension (Preproc_Out_Fmt))
            then
               Fail_CLI
                 (CLI_Output_Extension_Mismatch,
                  Use_Color,
                  Input_Extension (Preproc_Out_Fmt),
                  Input_Format_Image (Preproc_Out_Fmt));
               return Ada.Command_Line.Failure;
            end if;

            begin
               declare
                  Source_Text : constant String :=
                    (if Have_Input then Read_File (To_String (Input_Path))
                     elsif Have_Injected_Text then Injected_Text
                     else Read_Stdin_Text);
               begin
                  return Run_Preproc
                    (Source_Text,
                     To_String (Output_Path),
                     Have_Output,
                     Binds,
                     Warn,
                     Use_Color);
               end;
            exception
               when E : others =>
                  Emit_Error_Line
                    (Format_Line
                       (CLI_IO_Error,
                        0,
                        0,
                        Ada.Exceptions.Exception_Message (E)),
                     Use_Color);
                  return Ada.Command_Line.Failure;
            end;
         end if;

         if To_String (Cmd) = "tokenize" then
            if Have_Output_Format then
               if To_String (Output_Format_Text) /= "tokens" then
                  Fail_CLI
                    (CLI_Unknown_Output_Format,
                     Use_Color,
                     To_String (Output_Format_Text),
                     "tokenize");
                  return Ada.Command_Line.Failure;
               end if;
            end if;

            if Have_Output
              and then not Ends_With (To_String (Output_Path), ".tokens")
            then
               Fail_CLI
                 (CLI_Output_Extension_Mismatch,
                  Use_Color,
                  ".tokens",
                  "tokens");
               return Ada.Command_Line.Failure;
            end if;

            begin
               case In_Fmt is
                  when Mxeml =>
                     declare
                        Source_Text : constant String :=
                          (if Have_Input then
                             Read_File (To_String (Input_Path))
                           elsif Have_Injected_Text then Injected_Text
                           else Read_Stdin_Text);
                     begin
                        return Run_Tokenize_Mxeml
                          (Source_Text,
                           To_String (Output_Path),
                           Have_Output,
                           Binds,
                           Warn,
                           Use_Color);
                     end;

                  when Teml =>
                     declare
                        Source_Text : constant String :=
                          (if Have_Input then
                             Read_File (To_String (Input_Path))
                           elsif Have_Injected_Text then Injected_Text
                           else Read_Stdin_Text);
                     begin
                        return Run_Tokenize_Teml
                          (Source_Text,
                           To_String (Output_Path),
                           Have_Output,
                           Binds,
                           Warn,
                           Use_Color);
                     end;

                  when Stack_Eml =>
                     declare
                        Source_Text : constant String :=
                          (if Have_Input then
                             Read_File (To_String (Input_Path))
                           elsif Have_Injected_Text then Injected_Text
                           else Read_Stdin_Text);
                     begin
                        return Run_Tokenize_Eml
                          (Source_Text,
                           To_String (Output_Path),
                           Have_Output,
                           Use_Color);
                     end;

                  when Beml =>
                     return Ada.Command_Line.Failure;
               end case;
            exception
               when E : others =>
                  Emit_Error_Line
                    (Format_Line
                       (CLI_IO_Error,
                        0,
                        0,
                        Ada.Exceptions.Exception_Message (E)),
                     Use_Color);
                  return Ada.Command_Line.Failure;
            end;
         end if;

         if To_String (Cmd) = "parse" then
            if Have_Output_Format then
               Tree_Fmt :=
                 Parse_Tree_Format (To_String (Output_Format_Text), Format_Ok);
               if not Format_Ok then
                  Fail_CLI
                    (CLI_Unknown_Output_Format,
                     Use_Color,
                     To_String (Output_Format_Text),
                     "parse");
                  return Ada.Command_Line.Failure;
               end if;
            end if;

            if Have_Output
              and then not Ends_With
                (To_String (Output_Path), Tree_Extension (Tree_Fmt))
            then
               Fail_CLI
                 (CLI_Output_Extension_Mismatch,
                  Use_Color,
                  Tree_Extension (Tree_Fmt),
                  (if Have_Output_Format
                   then To_String (Output_Format_Text)
                   else "mermaid"));
               return Ada.Command_Line.Failure;
            end if;

            begin
               case In_Fmt is
                  when Mxeml =>
                     declare
                        Source_Text : constant String :=
                          (if Have_Input then
                             Read_File (To_String (Input_Path))
                           elsif Have_Injected_Text then Injected_Text
                           else Read_Stdin_Text);
                     begin
                        return Run_Parse_Mxeml
                          (Source_Text,
                           To_String (Output_Path),
                           Have_Output,
                           Tree_Fmt,
                           Binds,
                           Warn,
                           Use_Color);
                     end;

                  when Teml =>
                     declare
                        Source_Text : constant String :=
                          (if Have_Input then
                             Read_File (To_String (Input_Path))
                           elsif Have_Injected_Text then Injected_Text
                           else Read_Stdin_Text);
                     begin
                        return Run_Parse_Teml
                          (Source_Text,
                           To_String (Output_Path),
                           Have_Output,
                           Tree_Fmt,
                           Binds,
                           Warn,
                           Use_Color);
                     end;

                  when Stack_Eml =>
                     declare
                        Source_Text : constant String :=
                          (if Have_Input then
                             Read_File (To_String (Input_Path))
                           elsif Have_Injected_Text then Injected_Text
                           else Read_Stdin_Text);
                     begin
                        return Run_Parse_Eml
                          (Source_Text,
                           To_String (Output_Path),
                           Have_Output,
                           Tree_Fmt,
                           Use_Color);
                     end;

                  when Beml =>
                     declare
                        Source_Bin :
                          constant Ada.Streams.Stream_Element_Array :=
                          (if Have_Input then
                             Read_Binary_File (To_String (Input_Path))
                           elsif Have_Injected_Bin then Injected_Bin
                           else Read_Stdin_Binary);
                     begin
                        return Run_Parse_Beml
                          (Source_Bin,
                           To_String (Output_Path),
                           Have_Output,
                           Tree_Fmt,
                           Use_Color);
                     end;
               end case;
            exception
               when E : others =>
                  Emit_Error_Line
                    (Format_Line
                       (CLI_IO_Error,
                        0,
                        0,
                        Ada.Exceptions.Exception_Message (E)),
                     Use_Color);
                  return Ada.Command_Line.Failure;
            end;
         end if;

         --  run
         if To_String (Cmd) = "run" then
            if Have_Output then
               Fail_CLI (CLI_Run_Rejects_Output, Use_Color);
               return Ada.Command_Line.Failure;
            end if;
            if Have_Output_Format then
               Fail_CLI (CLI_Run_Rejects_Output_Format, Use_Color);
               return Ada.Command_Line.Failure;
            end if;

            begin
               case In_Fmt is
                  when Mxeml | Teml | Stack_Eml =>
                     declare
                        Source_Text : constant String :=
                          (if Have_Input then
                             Read_File (To_String (Input_Path))
                           elsif Have_Injected_Text then Injected_Text
                           else Read_Stdin_Text);
                     begin
                        return Run_Interpret
                          (In_Fmt,
                           Source_Text,
                           Empty_Stream,
                           Binds,
                           Warn,
                           Use_Color);
                     end;

                  when Beml =>
                     declare
                        Source_Bin :
                          constant Ada.Streams.Stream_Element_Array :=
                          (if Have_Input then
                             Read_Binary_File (To_String (Input_Path))
                           elsif Have_Injected_Bin then Injected_Bin
                           else Read_Stdin_Binary);
                     begin
                        return Run_Interpret
                          (In_Fmt,
                           "",
                           Source_Bin,
                           Binds,
                           Warn,
                           Use_Color);
                     end;
               end case;
            exception
               when E : others =>
                  Emit_Error_Line
                    (Format_Line
                       (CLI_IO_Error,
                        0,
                        0,
                        Ada.Exceptions.Exception_Message (E)),
                     Use_Color);
                  return Ada.Command_Line.Failure;
            end;
         end if;

         --  compile
         if Have_Output_Format then
            Compile_Fmt :=
              Parse_Compile_Output_Format
                (To_String (Output_Format_Text), Compile_Ok);
            if not Compile_Ok then
               Fail_CLI
                 (CLI_Unknown_Output_Format,
                  Use_Color,
                  To_String (Output_Format_Text),
                  "compile");
               return Ada.Command_Line.Failure;
            end if;
         end if;

         if (In_Fmt = Stack_Eml and then Compile_Fmt = Eml_Text)
           or else (In_Fmt = Beml and then Compile_Fmt = Beml_Binary)
         then
            Fail_CLI
              (CLI_Same_Format_Compile,
               Use_Color,
               Input_Format_Image (In_Fmt));
            return Ada.Command_Line.Failure;
         end if;

         if Have_Output
           and then not Ends_With
             (To_String (Output_Path), Compile_Extension (Compile_Fmt))
         then
            Fail_CLI
              (CLI_Output_Extension_Mismatch,
               Use_Color,
               Compile_Extension (Compile_Fmt),
               (if Have_Output_Format
                then To_String (Output_Format_Text)
                else Compile_Format_Image (Compile_Fmt)));
            return Ada.Command_Line.Failure;
         end if;

         begin
            case In_Fmt is
               when Mxeml | Teml | Stack_Eml =>
                  declare
                     Source_Text : constant String :=
                       (if Have_Input then
                          Read_File (To_String (Input_Path))
                        elsif Have_Injected_Text then Injected_Text
                        else Read_Stdin_Text);
                  begin
                     return Run_Emlir
                       (Source_Label,
                        In_Fmt,
                        Source_Text,
                        Empty_Stream,
                        To_String (Output_Path),
                        Have_Output,
                        Compile_Fmt,
                        Binds,
                        Warn,
                        Use_Color);
                  end;

               when Beml =>
                  declare
                     Source_Bin :
                       constant Ada.Streams.Stream_Element_Array :=
                       (if Have_Input then
                          Read_Binary_File (To_String (Input_Path))
                        elsif Have_Injected_Bin then Injected_Bin
                        else Read_Stdin_Binary);
                  begin
                     return Run_Emlir
                       (Source_Label,
                        In_Fmt,
                        "",
                        Source_Bin,
                        To_String (Output_Path),
                        Have_Output,
                        Compile_Fmt,
                        Binds,
                        Warn,
                        Use_Color);
                  end;
            end case;
         exception
            when E : others =>
               Emit_Error_Line
                 (Format_Line
                    (CLI_IO_Error,
                     0,
                     0,
                     Ada.Exceptions.Exception_Message (E)),
                  Use_Color);
               return Ada.Command_Line.Failure;
         end;
      end;
   end Run_Internal;

   function Run (Args : Arg_Array) return Ada.Command_Line.Exit_Status is
   begin
      return Run_Internal
        (Args,
         Injected_Text      => "",
         Have_Injected_Text => False,
         Injected_Bin       => Empty_Stream,
         Have_Injected_Bin  => False);
   end Run;

   function Run
     (Args       : Arg_Array;
      Stdin_Text : String) return Ada.Command_Line.Exit_Status
   is
   begin
      return Run_Internal
        (Args,
         Injected_Text      => Stdin_Text,
         Have_Injected_Text => True,
         Injected_Bin       => Empty_Stream,
         Have_Injected_Bin  => False);
   end Run;

   function Run
     (Args       : Arg_Array;
      Stdin_Data : Ada.Streams.Stream_Element_Array)
      return Ada.Command_Line.Exit_Status
   is
   begin
      return Run_Internal
        (Args,
         Injected_Text      => "",
         Have_Injected_Text => False,
         Injected_Bin       => Stdin_Data,
         Have_Injected_Bin  => True);
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
