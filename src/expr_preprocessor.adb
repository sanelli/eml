with Regex_Automata;

package body Expr_Preprocessor is

   use Ada.Strings.Unbounded;

   Variable_Pat : constant Regex_Automata.Engine :=
     Regex_Automata.Compile ("\$[A-Za-z_][A-Za-z0-9_]*");

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

   function Find_Binding
     (Bindings : Binding_Array; Name : String) return Natural
   is
   begin
      for I in Bindings'Range loop
         if To_String (Bindings (I).Name) = Name then
            return I;
         end if;
      end loop;
      return 0;
   end Find_Binding;

   function Preprocess
     (Source   : String;
      Bindings : Binding_Array) return Preprocess_Result
   is
      Result : Preprocess_Result;

      Text_Cap     : Natural := 64;
      Origin_Cap   : Natural := 64;
      Unbound_Cap  : Natural := 8;
      Unused_Cap   : Natural := Bindings'Length;
      Text_Buf     : String_Access := new String'(1 .. Text_Cap => ' ');
      Origin_Buf   : Expr_Tokenizer.Origin_Map_Access :=
        new Expr_Tokenizer.Origin_Map (1 .. Origin_Cap);
      Unbound_Buf  : Unbound_Array_Access :=
        new Unbound_Array (1 .. Unbound_Cap);
      Unused_Buf   : Name_Array_Access :=
        new Name_Array (1 .. Unused_Cap);
      Text_Len     : Natural := 0;
      Unbound_Cnt  : Natural := 0;
      Unused_Cnt   : Natural := 0;
      Used         : array (Bindings'Range) of Boolean :=
        (others => False);

      procedure Grow_Text is
         New_Cap : constant Natural := Text_Cap * 2;
         New_Buf : constant String_Access := new String'(1 .. New_Cap => ' ');
      begin
         New_Buf (1 .. Text_Len) := Text_Buf (1 .. Text_Len);
         Text_Buf := New_Buf;
         Text_Cap := New_Cap;
      end Grow_Text;

      procedure Grow_Origins is
         New_Cap : constant Natural := Origin_Cap * 2;
         New_Buf : constant Expr_Tokenizer.Origin_Map_Access :=
           new Expr_Tokenizer.Origin_Map (1 .. New_Cap);
      begin
         New_Buf (1 .. Text_Len) := Origin_Buf (1 .. Text_Len);
         Origin_Buf := New_Buf;
         Origin_Cap := New_Cap;
      end Grow_Origins;

      procedure Grow_Unbound is
         New_Cap : constant Natural := Unbound_Cap * 2;
         New_Buf : constant Unbound_Array_Access :=
           new Unbound_Array (1 .. New_Cap);
      begin
         New_Buf (1 .. Unbound_Cnt) := Unbound_Buf (1 .. Unbound_Cnt);
         Unbound_Buf := New_Buf;
         Unbound_Cap := New_Cap;
      end Grow_Unbound;

      procedure Append_Char
        (Ch : Character; Orig : Expr_Tokenizer.Origin)
      is
      begin
         if Text_Len = Text_Cap then
            Grow_Text;
            Grow_Origins;
         end if;
         Text_Len := Text_Len + 1;
         Text_Buf (Text_Len) := Ch;
         Origin_Buf (Text_Len) := Orig;
      end Append_Char;

      procedure Append_Text
        (Fragment : String; Orig : Expr_Tokenizer.Origin)
      is
      begin
         for I in Fragment'Range loop
            Append_Char (Fragment (I), Orig);
         end loop;
      end Append_Text;

      procedure Record_Unbound
        (L, C : Positive; Var : String)
      is
      begin
         if Unbound_Cnt = Unbound_Cap then
            Grow_Unbound;
         end if;
         Unbound_Cnt := Unbound_Cnt + 1;
         Unbound_Buf (Unbound_Cnt) :=
           (Line     => L,
            Column   => C,
            Var_Name => To_Unbounded_String (Var));
      end Record_Unbound;

      Pos    : Positive := Source'First;
      Line   : Positive := 1;
      Column : Positive := 1;

   begin
      if Source'Length = 0 then
         Result.Text := Null_Unbounded_String;
         Result.Origins :=
           new Expr_Tokenizer.Origin_Map (1 .. 0);
         Result.Unbound := new Unbound_Array (1 .. 0);
         if Bindings'Length > 0 then
            Result.Unused := new Name_Array (1 .. Bindings'Length);
            for I in Bindings'Range loop
               Result.Unused (I) := Bindings (I).Name;
            end loop;
         else
            Result.Unused := new Name_Array (1 .. 0);
         end if;
         Result.Had_Error := False;
         return Result;
      end if;

      while Pos <= Source'Last loop
         declare
            Start_Line   : constant Positive := Line;
            Start_Column : constant Positive := Column;
            Len          : constant Natural :=
              Regex_Automata.Match_Prefix (Variable_Pat, Source, Pos);
         begin
            if Len > 0 then
               declare
                  Var_Name : constant String :=
                    Source (Pos .. Pos + Len - 1);
                  Bidx     : constant Natural :=
                    Find_Binding (Bindings, Var_Name);
                  Var_Orig : constant Expr_Tokenizer.Origin :=
                    (Line     => Start_Line,
                     Column   => Start_Column,
                     From_Var => True,
                     Var_Name => To_Unbounded_String (Var_Name));
               begin
                  if Bidx = 0 then
                     Record_Unbound (Start_Line, Start_Column, Var_Name);
                     Append_Text (Var_Name, Var_Orig);
                  else
                     Used (Bidx) := True;
                     Append_Text
                       (To_String (Bindings (Bidx).Value), Var_Orig);
                  end if;
                  Advance_Position (Source, Pos, Len, Line, Column);
                  Pos := Pos + Len;
               end;
            else
               declare
                  Plain_Orig : constant Expr_Tokenizer.Origin :=
                    (Line     => Start_Line,
                     Column   => Start_Column,
                     From_Var => False,
                     Var_Name => Null_Unbounded_String);
               begin
                  Append_Char (Source (Pos), Plain_Orig);
                  Advance_Position (Source, Pos, 1, Line, Column);
                  Pos := Pos + 1;
               end;
            end if;
         end;
      end loop;

      Result.Text := To_Unbounded_String (Text_Buf (1 .. Text_Len));
      Result.Origins :=
        new Expr_Tokenizer.Origin_Map (1 .. Text_Len);
      for I in 1 .. Text_Len loop
         Result.Origins (I) := Origin_Buf (I);
      end loop;

      Result.Unbound := new Unbound_Array (1 .. Unbound_Cnt);
      for I in 1 .. Unbound_Cnt loop
         Result.Unbound (I) := Unbound_Buf (I);
      end loop;

      for I in Bindings'Range loop
         if not Used (I) then
            Unused_Cnt := Unused_Cnt + 1;
            Unused_Buf (Unused_Cnt) := Bindings (I).Name;
         end if;
      end loop;
      Result.Unused := new Name_Array (1 .. Unused_Cnt);
      for I in 1 .. Unused_Cnt loop
         Result.Unused (I) := Unused_Buf (I);
      end loop;

      Result.Had_Error := Unbound_Cnt > 0;
      return Result;
   end Preprocess;

end Expr_Preprocessor;
