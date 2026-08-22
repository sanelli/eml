package body Eml_Parser is

   use Ada.Strings.Unbounded;
   use Eml.Diagnostics;
   use IR_Eml;
   use type Eml_Tokenizer.Token_Kind;

   function Parse (Tokens : Eml_Tokenizer.Token_Array) return Parse_Result is
      Result : Parse_Result;
      Stack  : array (1 .. Tokens'Length + 1) of Node_Access;
      Top    : Natural := 0;

      procedure Fail
        (T : Eml_Tokenizer.Token;
         Id : Diagnostic_Id;
         Param1 : String := "")
      is
      begin
         Result.Had_Error := True;
         Result.Error_Id := Id;
         Result.Error_Line := T.Line;
         Result.Error_Col := T.Column;
         Result.Param1 := To_Unbounded_String (Param1);
         Result.Root := null;
      end Fail;

   begin
      if Tokens'Length = 0 then
         Result.Had_Error := True;
         Result.Error_Id := SE_Unexpected_EOI;
         Result.Error_Line := 1;
         Result.Error_Col := 1;
         return Result;
      end if;

      for T of Tokens loop
         case T.Kind is
            when Eml_Tokenizer.One =>
               Top := Top + 1;
               Stack (Top) := Make_One;
            when Eml_Tokenizer.Eml_Op =>
               if Top < 2 then
                  Fail (T, SE_Stack_Underflow);
                  return Result;
               end if;
               declare
                  Y : constant Node_Access := Stack (Top);
                  X : constant Node_Access := Stack (Top - 1);
                  Tag : constant String := To_String (T.Comment);
               begin
                  Top := Top - 2;
                  Top := Top + 1;
                  Stack (Top) :=
                    Make_Eml
                      (X,
                       Y,
                       (if Tag'Length > 0 then Tag else ""));
               end;
         end case;
      end loop;

      if Top /= 1 then
         Result.Had_Error := True;
         Result.Error_Id := SE_Stack_Not_Single;
         Result.Error_Line := Tokens (Tokens'Last).Line;
         Result.Error_Col := Tokens (Tokens'Last).Column;
         return Result;
      end if;

      Result.Root := Stack (1);
      return Result;
   end Parse;

end Eml_Parser;
