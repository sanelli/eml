with Regex_Automata;

package body Teml_Tokenizer is

   use Ada.Strings.Unbounded;
   use Eml.Diagnostics;

   Whitespace : constant Regex_Automata.Engine :=
     Regex_Automata.Compile ("[ \t\n\r]+");
   Eml_Pat : constant Regex_Automata.Engine :=
     Regex_Automata.Compile ("eml");
   One_Pat : constant Regex_Automata.Engine :=
     Regex_Automata.Compile ("1");
   LParen_Pat : constant Regex_Automata.Engine :=
     Regex_Automata.Compile ("\(");
   RParen_Pat : constant Regex_Automata.Engine :=
     Regex_Automata.Compile ("\)");
   Comma_Pat : constant Regex_Automata.Engine :=
     Regex_Automata.Compile (",");

   function Kind_Name (Kind : Token_Kind) return String is
   begin
      case Kind is
         when One =>
            return "ONE";
         when Eml_Kw =>
            return "EML";
         when LParen =>
            return "LPAREN";
         when RParen =>
            return "RPAREN";
         when Comma =>
            return "COMMA";
      end case;
   end Kind_Name;

   type Token_Buffer is array (Positive range <>) of Token;
   type Diag_Buffer is array (Positive range <>) of Diagnostic;

   procedure Advance_Position
     (Source : String;
      From   : Positive;
      Len    : Positive;
      Line   : in out Positive;
      Column : in out Positive)
   is
   begin
      for I in From .. From + Len - 1 loop
         if Source (I) = ASCII.LF then
            Line := Line + 1;
            Column := 1;
         else
            Column := Column + 1;
         end if;
      end loop;
   end Advance_Position;

   function Origin_At
     (Origins : Origin_Map_Access; Pos : Positive) return Origin
   is
   begin
      if Origins = null or else Pos > Origins'Last then
         return (Line => 1, Column => 1, others => <>);
      end if;
      return Origins (Pos);
   end Origin_At;

   function Match
     (Pat : Regex_Automata.Engine;
      Source : String;
      Pos : Positive) return Natural
   is
   begin
      return Regex_Automata.Match_Prefix (Pat, Source, Pos);
   end Match;

   function Tokenize_Internal
     (Source  : String;
      Origins : Origin_Map_Access) return Tokenize_Result
   is
      Result      : Tokenize_Result;
      Tokens_Buf  : Token_Buffer (1 .. Source'Length + 1);
      Diags_Buf   : Diag_Buffer (1 .. Source'Length + 1);
      Token_Count : Natural := 0;
      Diag_Count  : Natural := 0;
      Had_Errors  : Boolean := False;
      Pos         : Natural := Source'First;
      Line        : Positive := 1;
      Column      : Positive := 1;
      Use_Origins : constant Boolean := Origins /= null;

      procedure Emit_Token
        (Kind     : Token_Kind;
         Lex      : String;
         L, C     : Positive;
         From_Var : Boolean;
         Var_Name : Unbounded_String)
      is
      begin
         Token_Count := Token_Count + 1;
         Tokens_Buf (Token_Count) :=
           (Kind     => Kind,
            Lexeme   => To_Unbounded_String (Lex),
            Line     => L,
            Column   => C,
            From_Var => From_Var,
            Var_Name => Var_Name);
      end Emit_Token;

      procedure Emit_Diag
        (L, C     : Positive;
         Id       : Diagnostic_Id;
         Param1   : String;
         From_Var : Boolean;
         Var_Name : Unbounded_String)
      is
      begin
         Had_Errors := True;
         Diag_Count := Diag_Count + 1;
         Diags_Buf (Diag_Count) :=
           (Id       => Id,
            Line     => L,
            Column   => C,
            Param1   => To_Unbounded_String (Param1),
            From_Var => From_Var,
            Var_Name => Var_Name);
      end Emit_Diag;

   begin
      if Source'Length = 0 then
         Result.Tokens := new Token_Array (1 .. 0);
         Result.Diagnostics := new Diagnostic_Array (1 .. 0);
         return Result;
      end if;

      while Pos <= Source'Last loop
         declare
            Start_Pos    : constant Natural := Pos;
            Start_Line   : constant Positive := Line;
            Start_Column : constant Positive := Column;
            Len          : Natural;
            Orig         : Origin;
         begin
            Len := Match (Whitespace, Source, Pos);
            if Len > 0 then
               Advance_Position (Source, Pos, Len, Line, Column);
               Pos := Pos + Len;
            else
               if Use_Origins then
                  Orig := Origin_At (Origins, Start_Pos);
               end if;

               if Match (Eml_Pat, Source, Pos) = 3 then
                  Emit_Token
                    (Eml_Kw,
                     "eml",
                     Start_Line,
                     Start_Column,
                     (if Use_Origins then Orig.From_Var else False),
                     (if Use_Origins then Orig.Var_Name
                      else Null_Unbounded_String));
                  Advance_Position (Source, Pos, 3, Line, Column);
                  Pos := Pos + 3;
               elsif Match (One_Pat, Source, Pos) = 1 then
                  Emit_Token
                    (One,
                     "1",
                     Start_Line,
                     Start_Column,
                     (if Use_Origins then Orig.From_Var else False),
                     (if Use_Origins then Orig.Var_Name
                      else Null_Unbounded_String));
                  Advance_Position (Source, Pos, 1, Line, Column);
                  Pos := Pos + 1;
               elsif Match (LParen_Pat, Source, Pos) > 0 then
                  Emit_Token
                    (LParen,
                     "(",
                     Start_Line,
                     Start_Column,
                     (if Use_Origins then Orig.From_Var else False),
                     (if Use_Origins then Orig.Var_Name
                      else Null_Unbounded_String));
                  Advance_Position (Source, Pos, 1, Line, Column);
                  Pos := Pos + 1;
               elsif Match (RParen_Pat, Source, Pos) > 0 then
                  Emit_Token
                    (RParen,
                     ")",
                     Start_Line,
                     Start_Column,
                     (if Use_Origins then Orig.From_Var else False),
                     (if Use_Origins then Orig.Var_Name
                      else Null_Unbounded_String));
                  Advance_Position (Source, Pos, 1, Line, Column);
                  Pos := Pos + 1;
               elsif Match (Comma_Pat, Source, Pos) > 0 then
                  Emit_Token
                    (Comma,
                     ",",
                     Start_Line,
                     Start_Column,
                     (if Use_Origins then Orig.From_Var else False),
                     (if Use_Origins then Orig.Var_Name
                      else Null_Unbounded_String));
                  Advance_Position (Source, Pos, 1, Line, Column);
                  Pos := Pos + 1;
               else
                  Emit_Diag
                    (Start_Line,
                     Start_Column,
                     TM_Unexpected_Character,
                     Source (Pos .. Pos),
                     (if Use_Origins then Orig.From_Var else False),
                     (if Use_Origins then Orig.Var_Name
                      else Null_Unbounded_String));
                  Advance_Position (Source, Pos, 1, Line, Column);
                  Pos := Pos + 1;
               end if;
            end if;
         end;
      end loop;

      if Token_Count = 0 then
         Result.Tokens := new Token_Array (1 .. 0);
      else
         Result.Tokens := new Token_Array (1 .. Token_Count);
         for I in 1 .. Token_Count loop
            Result.Tokens (I) := Tokens_Buf (I);
         end loop;
      end if;

      if Diag_Count = 0 then
         Result.Diagnostics := new Diagnostic_Array (1 .. 0);
      else
         Result.Diagnostics := new Diagnostic_Array (1 .. Diag_Count);
         for I in 1 .. Diag_Count loop
            Result.Diagnostics (I) := Diags_Buf (I);
         end loop;
      end if;

      Result.Had_Errors := Had_Errors;
      return Result;
   end Tokenize_Internal;

   function Tokenize (Source : String) return Tokenize_Result is
   begin
      return Tokenize_Internal (Source, null);
   end Tokenize;

   function Tokenize
     (Source  : String;
      Origins : Origin_Map_Access) return Tokenize_Result
   is
   begin
      return Tokenize_Internal (Source, Origins);
   end Tokenize;

   function Trim_Image (N : Positive) return String is
      S : constant String := Positive'Image (N);
   begin
      if S'Length > 0 and then S (S'First) = ' ' then
         return S (S'First + 1 .. S'Last);
      end if;
      return S;
   end Trim_Image;

   function Same_Var_Span (A, B : Token) return Boolean is
   begin
      return A.From_Var
        and then B.From_Var
        and then A.Line = B.Line
        and then A.Column = B.Column
        and then A.Var_Name = B.Var_Name;
   end Same_Var_Span;

   procedure Write_One (File : Ada.Text_IO.File_Type; T : Token) is
   begin
      Ada.Text_IO.Put_Line
        (File,
         Trim_Image (T.Line)
         & ":"
         & Trim_Image (T.Column)
         & " "
         & Kind_Name (T.Kind)
         & " "
         & To_String (T.Lexeme));
   end Write_One;

   procedure Write_Dump
     (Tokens : Token_Array;
      File   : Ada.Text_IO.File_Type)
   is
      In_Var_Run : Boolean := False;
      Run_Var    : Unbounded_String;
   begin
      for I in Tokens'Range loop
         declare
            T : constant Token := Tokens (I);
         begin
            if T.From_Var then
               if not In_Var_Run
                 or else (I > Tokens'First
                          and then not Same_Var_Span (Tokens (I - 1), T))
               then
                  if In_Var_Run then
                     Ada.Text_IO.Put_Line
                       (File, "-- " & To_String (Run_Var) & " end");
                  end if;
                  Ada.Text_IO.Put_Line
                    (File, "-- " & To_String (T.Var_Name) & " begin");
                  In_Var_Run := True;
                  Run_Var := T.Var_Name;
               end if;
            else
               if In_Var_Run then
                  Ada.Text_IO.Put_Line
                    (File, "-- " & To_String (Run_Var) & " end");
                  In_Var_Run := False;
               end if;
            end if;
            Write_One (File, T);
         end;
      end loop;
      if In_Var_Run then
         Ada.Text_IO.Put_Line (File, "-- " & To_String (Run_Var) & " end");
      end if;
   end Write_Dump;

   procedure Write_Dump_To_Stdout (Tokens : Token_Array) is
   begin
      Write_Dump (Tokens, Ada.Text_IO.Standard_Output);
   end Write_Dump_To_Stdout;

end Teml_Tokenizer;
