with Regex_Automata;

package body Expr_Tokenizer is

   use Ada.Strings.Unbounded;

   Whitespace : constant Regex_Automata.Engine :=
     Regex_Automata.Compile ("[ \t\n\r]+");
   Number_Pat : constant Regex_Automata.Engine :=
     Regex_Automata.Compile ("[0-9]+(\.[0-9]+)?([eE][+\-]?[0-9]+)?");
   Word_Pat : constant Regex_Automata.Engine :=
     Regex_Automata.Compile ("[A-Za-z][A-Za-z0-9]*");
   Variable_Pat : constant Regex_Automata.Engine :=
     Regex_Automata.Compile ("\$[A-Za-z_][A-Za-z0-9_]*");
   Plus_Pat : constant Regex_Automata.Engine :=
     Regex_Automata.Compile ("\+");
   Minus_Pat : constant Regex_Automata.Engine :=
     Regex_Automata.Compile ("\-");
   Star_Pat : constant Regex_Automata.Engine :=
     Regex_Automata.Compile ("\*");
   Slash_Pat : constant Regex_Automata.Engine :=
     Regex_Automata.Compile ("/");
   Caret_Pat : constant Regex_Automata.Engine :=
     Regex_Automata.Compile ("\^");
   LParen_Pat : constant Regex_Automata.Engine :=
     Regex_Automata.Compile ("\(");
   RParen_Pat : constant Regex_Automata.Engine :=
     Regex_Automata.Compile ("\)");

   function Kind_Name (Kind : Token_Kind) return String is
   begin
      case Kind is
         when Plus =>
            return "PLUS";
         when Minus =>
            return "MINUS";
         when Star =>
            return "STAR";
         when Slash =>
            return "SLASH";
         when Caret =>
            return "CARET";
         when LParen =>
            return "LPAREN";
         when RParen =>
            return "RPAREN";
         when Number =>
            return "NUMBER";
         when Function_Name =>
            return "FUNCTION";
         when Constant_Name =>
            return "CONSTANT";
         when Variable =>
            return "VARIABLE";
      end case;
   end Kind_Name;

   function Is_Function (Word : String) return Boolean is
     (Word = "log"
      or else Word = "sin"
      or else Word = "cos"
      or else Word = "tan"
      or else Word = "sqrt"
      or else Word = "sinh"
      or else Word = "cosh"
      or else Word = "tanh");

   function Is_Constant (Word : String) return Boolean is
     (Word = "i"
      or else Word = "pi"
      or else Word = "e"
      or else Word = "phi");

   type Token_Buffer is array (Positive range <>) of Token;
   type Token_Buffer_Access is access Token_Buffer;
   type Diag_Buffer is array (Positive range <>) of Diagnostic;
   type Diag_Buffer_Access is access Diag_Buffer;

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

   function Tokenize (Source : String) return Tokenize_Result is
      Tokens_Cap : Natural := 16;
      Diags_Cap  : Natural := 8;
      Tokens_Buf : Token_Buffer_Access := new Token_Buffer (1 .. Tokens_Cap);
      Diags_Buf  : Diag_Buffer_Access := new Diag_Buffer (1 .. Diags_Cap);
      Token_Count : Natural := 0;
      Diag_Count  : Natural := 0;
      Pos         : Positive := Source'First;
      Line        : Positive := 1;
      Column      : Positive := 1;
      Result      : Tokenize_Result;
      Had_Errors  : Boolean := False;

      procedure Grow_Tokens is
         New_Cap : constant Natural := Tokens_Cap * 2;
         New_Buf : constant Token_Buffer_Access :=
           new Token_Buffer (1 .. New_Cap);
      begin
         New_Buf (1 .. Token_Count) := Tokens_Buf (1 .. Token_Count);
         Tokens_Buf := New_Buf;
         Tokens_Cap := New_Cap;
      end Grow_Tokens;

      procedure Grow_Diags is
         New_Cap : constant Natural := Diags_Cap * 2;
         New_Buf : constant Diag_Buffer_Access :=
           new Diag_Buffer (1 .. New_Cap);
      begin
         New_Buf (1 .. Diag_Count) := Diags_Buf (1 .. Diag_Count);
         Diags_Buf := New_Buf;
         Diags_Cap := New_Cap;
      end Grow_Diags;

      procedure Emit_Token
        (Kind : Token_Kind; Lex : String; L, C : Positive)
      is
      begin
         if Token_Count = Tokens_Cap then
            Grow_Tokens;
         end if;
         Token_Count := Token_Count + 1;
         Tokens_Buf (Token_Count) :=
           (Kind   => Kind,
            Lexeme => To_Unbounded_String (Lex),
            Line   => L,
            Column => C);
      end Emit_Token;

      procedure Emit_Diag (L, C : Positive; Message : String) is
      begin
         Had_Errors := True;
         if Diag_Count = Diags_Cap then
            Grow_Diags;
         end if;
         Diag_Count := Diag_Count + 1;
         Diags_Buf (Diag_Count) :=
           (Line    => L,
            Column  => C,
            Message => To_Unbounded_String (Message));
      end Emit_Diag;

      function Match
        (E : Regex_Automata.Engine; At_Pos : Positive) return Natural
      is
         (Regex_Automata.Match_Prefix (E, Source, At_Pos));

   begin
      if Source'Length = 0 then
         Result.Tokens := new Token_Array (1 .. 0);
         Result.Diagnostics := new Diagnostic_Array (1 .. 0);
         Result.Had_Errors := False;
         return Result;
      end if;

      while Pos <= Source'Last loop
         declare
            Start_Line   : constant Positive := Line;
            Start_Column : constant Positive := Column;
            Len          : Natural;
         begin
            Len := Match (Whitespace, Pos);
            if Len > 0 then
               Advance_Position (Source, Pos, Len, Line, Column);
               Pos := Pos + Len;
            else
               Len := Match (Number_Pat, Pos);
               if Len > 0 then
                  Emit_Token
                    (Number, Source (Pos .. Pos + Len - 1),
                     Start_Line, Start_Column);
                  Advance_Position (Source, Pos, Len, Line, Column);
                  Pos := Pos + Len;
               else
                  Len := Match (Variable_Pat, Pos);
                  if Len > 0 then
                     Emit_Token
                       (Variable, Source (Pos .. Pos + Len - 1),
                        Start_Line, Start_Column);
                     Advance_Position (Source, Pos, Len, Line, Column);
                     Pos := Pos + Len;
                  else
                     Len := Match (Word_Pat, Pos);
                     if Len > 0 then
                        declare
                           Word : constant String :=
                             Source (Pos .. Pos + Len - 1);
                        begin
                           if Is_Function (Word) then
                              Emit_Token
                                (Function_Name, Word,
                                 Start_Line, Start_Column);
                           elsif Is_Constant (Word) then
                              Emit_Token
                                (Constant_Name, Word,
                                 Start_Line, Start_Column);
                           else
                              Emit_Diag
                                (Start_Line,
                                 Start_Column,
                                 "unknown identifier '" & Word & "'");
                           end if;
                           Advance_Position (Source, Pos, Len, Line, Column);
                           Pos := Pos + Len;
                        end;
                     elsif Match (Plus_Pat, Pos) > 0 then
                        Emit_Token
                          (Plus, "+", Start_Line, Start_Column);
                        Advance_Position (Source, Pos, 1, Line, Column);
                        Pos := Pos + 1;
                     elsif Match (Minus_Pat, Pos) > 0 then
                        Emit_Token
                          (Minus, "-", Start_Line, Start_Column);
                        Advance_Position (Source, Pos, 1, Line, Column);
                        Pos := Pos + 1;
                     elsif Match (Star_Pat, Pos) > 0 then
                        Emit_Token
                          (Star, "*", Start_Line, Start_Column);
                        Advance_Position (Source, Pos, 1, Line, Column);
                        Pos := Pos + 1;
                     elsif Match (Slash_Pat, Pos) > 0 then
                        Emit_Token
                          (Slash, "/", Start_Line, Start_Column);
                        Advance_Position (Source, Pos, 1, Line, Column);
                        Pos := Pos + 1;
                     elsif Match (Caret_Pat, Pos) > 0 then
                        Emit_Token
                          (Caret, "^", Start_Line, Start_Column);
                        Advance_Position (Source, Pos, 1, Line, Column);
                        Pos := Pos + 1;
                     elsif Match (LParen_Pat, Pos) > 0 then
                        Emit_Token
                          (LParen, "(", Start_Line, Start_Column);
                        Advance_Position (Source, Pos, 1, Line, Column);
                        Pos := Pos + 1;
                     elsif Match (RParen_Pat, Pos) > 0 then
                        Emit_Token
                          (RParen, ")", Start_Line, Start_Column);
                        Advance_Position (Source, Pos, 1, Line, Column);
                        Pos := Pos + 1;
                     else
                        Emit_Diag
                          (Start_Line,
                           Start_Column,
                           "unexpected character '"
                           & Source (Pos .. Pos)
                           & "'");
                        Advance_Position (Source, Pos, 1, Line, Column);
                        Pos := Pos + 1;
                     end if;
                  end if;
               end if;
            end if;
         end;
      end loop;

      Result.Tokens := new Token_Array (1 .. Token_Count);
      for I in 1 .. Token_Count loop
         Result.Tokens (I) := Tokens_Buf (I);
      end loop;
      Result.Diagnostics := new Diagnostic_Array (1 .. Diag_Count);
      for I in 1 .. Diag_Count loop
         Result.Diagnostics (I) := Diags_Buf (I);
      end loop;
      Result.Had_Errors := Had_Errors;
      return Result;
   end Tokenize;

   function Trim_Image (N : Positive) return String is
      S : constant String := Positive'Image (N);
   begin
      if S'Length > 0 and then S (S'First) = ' ' then
         return S (S'First + 1 .. S'Last);
      end if;
      return S;
   end Trim_Image;

   procedure Write_One
     (File : Ada.Text_IO.File_Type; T : Token)
   is
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
   begin
      for T of Tokens loop
         Write_One (File, T);
      end loop;
   end Write_Dump;

   procedure Write_Dump_To_Stdout (Tokens : Token_Array) is
   begin
      Write_Dump (Tokens, Ada.Text_IO.Standard_Output);
   end Write_Dump_To_Stdout;

end Expr_Tokenizer;
