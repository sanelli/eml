with Regex_Automata;

package body Eml_Tokenizer is

   use Ada.Strings.Unbounded;
   use Eml.Diagnostics;

   Whitespace : constant Regex_Automata.Engine :=
     Regex_Automata.Compile ("[ \t\n\r]+");
   Comment_Line : constant Regex_Automata.Engine :=
     Regex_Automata.Compile ("--[^\n\r]*(\n|\r\n|\r|$)");
   One_Pat : constant Regex_Automata.Engine :=
     Regex_Automata.Compile ("ONE");
   Eml_Pat : constant Regex_Automata.Engine :=
     Regex_Automata.Compile ("EML");

   function Kind_Name (Kind : Token_Kind) return String is
   begin
      case Kind is
         when One =>
            return "ONE";
         when Eml_Op =>
            return "EML";
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

   function Match
     (Pat : Regex_Automata.Engine;
      Source : String;
      Pos : Positive) return Natural
   is
   begin
      return Regex_Automata.Match_Prefix (Pat, Source, Pos);
   end Match;

   function Extract_Eml_Comment
     (Source : String; After : Positive) return String
   is
      Pos : Natural := After;
   begin
      while Pos <= Source'Last
        and then Source (Pos) in ' ' | ASCII.HT
      loop
         Pos := Pos + 1;
      end loop;
      if Pos + 1 <= Source'Last
        and then Source (Pos) = '-'
        and then Source (Pos + 1) = '-'
      then
         Pos := Pos + 2;
         while Pos <= Source'Last
           and then Source (Pos) in ' ' | ASCII.HT
         loop
            Pos := Pos + 1;
         end loop;
         declare
            Start : constant Natural := Pos;
         begin
            while Pos <= Source'Last and then Source (Pos) /= ASCII.LF loop
               Pos := Pos + 1;
            end loop;
            if Start <= Source'Last then
               return Source (Start .. Pos - 1);
            end if;
         end;
      end if;
      return "";
   end Extract_Eml_Comment;

   function Tokenize (Source : String) return Tokenize_Result is
      Result      : Tokenize_Result;
      Tokens_Buf  : Token_Buffer (1 .. Source'Length + 1);
      Diags_Buf   : Diag_Buffer (1 .. Source'Length + 1);
      Token_Count : Natural := 0;
      Diag_Count  : Natural := 0;
      Had_Errors  : Boolean := False;
      Pos         : Natural := Source'First;
      Line        : Positive := 1;
      Column      : Positive := 1;

      procedure Emit_Token
        (Kind    : Token_Kind;
         Lex     : String;
         Comment : String;
         L, C    : Positive)
      is
      begin
         Token_Count := Token_Count + 1;
         Tokens_Buf (Token_Count) :=
           (Kind    => Kind,
            Lexeme  => To_Unbounded_String (Lex),
            Comment => To_Unbounded_String (Comment),
            Line    => L,
            Column  => C);
      end Emit_Token;

      procedure Emit_Diag
        (L, C : Positive; Id : Diagnostic_Id; Param1 : String)
      is
      begin
         Had_Errors := True;
         Diag_Count := Diag_Count + 1;
         Diags_Buf (Diag_Count) :=
           (Id     => Id,
            Line   => L,
            Column => C,
            Param1 => To_Unbounded_String (Param1));
      end Emit_Diag;

   begin
      if Source'Length = 0 then
         Result.Tokens := new Token_Array (1 .. 0);
         Result.Diagnostics := new Diagnostic_Array (1 .. 0);
         return Result;
      end if;

      while Pos <= Source'Last loop
         declare
            Start_Line   : constant Positive := Line;
            Start_Column : constant Positive := Column;
            Len          : Natural;
         begin
            Len := Match (Whitespace, Source, Pos);
            if Len > 0 then
               Advance_Position (Source, Pos, Len, Line, Column);
               Pos := Pos + Len;
            else
               Len := Match (Comment_Line, Source, Pos);
               if Len > 0 then
                  Advance_Position (Source, Pos, Len, Line, Column);
                  Pos := Pos + Len;
               elsif Match (One_Pat, Source, Pos) = 3 then
                  Emit_Token (One, "ONE", "", Start_Line, Start_Column);
                  Advance_Position (Source, Pos, 3, Line, Column);
                  Pos := Pos + 3;
               elsif Match (Eml_Pat, Source, Pos) = 3 then
                  declare
                     Tag : constant String :=
                       Extract_Eml_Comment (Source, Pos + 3);
                  begin
                     Emit_Token (Eml_Op, "EML", Tag, Start_Line, Start_Column);
                     Advance_Position (Source, Pos, 3, Line, Column);
                     Pos := Pos + 3;
                     if Tag'Length > 0 then
                        declare
                           Skip : Natural := Pos;
                        begin
                           while Skip <= Source'Last
                             and then Source (Skip) /= ASCII.LF
                           loop
                              Skip := Skip + 1;
                           end loop;
                           if Skip > Pos then
                              Advance_Position
                                (Source, Pos, Skip - Pos, Line, Column);
                              Pos := Skip;
                           end if;
                        end;
                     end if;
                  end;
               else
                  declare
                     Word_Len : Natural := 0;
                  begin
                     if Source (Pos) in 'A' .. 'Z' | 'a' .. 'z' then
                        Word_Len := 1;
                        while Pos + Word_Len <= Source'Last
                          and then Source (Pos + Word_Len) in
                                'A' .. 'Z' | 'a' .. 'z' | '0' .. '9'
                        loop
                           Word_Len := Word_Len + 1;
                        end loop;
                        Emit_Diag
                          (Start_Line,
                           Start_Column,
                           SE_Unknown_Identifier,
                           Source (Pos .. Pos + Word_Len - 1));
                        Advance_Position
                          (Source, Pos, Word_Len, Line, Column);
                        Pos := Pos + Word_Len;
                     else
                        Emit_Diag
                          (Start_Line,
                           Start_Column,
                           SE_Unexpected_Character,
                           Source (Pos .. Pos));
                        Advance_Position (Source, Pos, 1, Line, Column);
                        Pos := Pos + 1;
                     end if;
                  end;
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
   end Tokenize;

   function Trim_Image (N : Positive) return String is
      S : constant String := Positive'Image (N);
   begin
      if S'Length > 0 and then S (S'First) = ' ' then
         return S (S'First + 1 .. S'Last);
      end if;
      return S;
   end Trim_Image;

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
   begin
      for T of Tokens loop
         Write_One (File, T);
      end loop;
   end Write_Dump;

   procedure Write_Dump_To_Stdout (Tokens : Token_Array) is
   begin
      Write_Dump (Tokens, Ada.Text_IO.Standard_Output);
   end Write_Dump_To_Stdout;

end Eml_Tokenizer;
