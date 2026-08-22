package body Teml_Parser is

   use Ada.Strings.Unbounded;
   use Eml.Diagnostics;
   use IR_Eml;
   use type Teml_Tokenizer.Token_Kind;

   function Parse (Tokens : Teml_Tokenizer.Token_Array) return Parse_Result is
      Pos    : Natural := Tokens'First;
      Result : Parse_Result;

      procedure Fail_Tok
        (T : Teml_Tokenizer.Token;
         Id : Diagnostic_Id;
         Param1 : String := "")
      is
      begin
         Result.Had_Error := True;
         Result.Error_Id := Id;
         Result.Error_Line := T.Line;
         Result.Error_Col := T.Column;
         Result.Param1 := To_Unbounded_String (Param1);
         Result.From_Var := T.From_Var;
         Result.Var_Name := T.Var_Name;
         Result.Root := null;
      end Fail_Tok;

      function At_End return Boolean is
        (Pos > Tokens'Last);

      function Peek return Teml_Tokenizer.Token is
        (Tokens (Pos));

      procedure Advance is
      begin
         Pos := Pos + 1;
      end Advance;

      function Parse_S return Node_Access;

      function Parse_S return Node_Access is
      begin
         if At_End then
            if Tokens'Length = 0 then
               Result.Had_Error := True;
               Result.Error_Id := TM_Unexpected_EOI;
               Result.Error_Line := 1;
               Result.Error_Col := 1;
               return null;
            else
               Fail_Tok (Tokens (Tokens'Last), TM_Unexpected_EOI);
               return null;
            end if;
         end if;

         declare
            T : constant Teml_Tokenizer.Token := Peek;
         begin
            if T.Kind = Teml_Tokenizer.One then
               Advance;
               return Make_One;
            elsif T.Kind = Teml_Tokenizer.Eml_Kw then
               Advance;
               if At_End or else Peek.Kind /= Teml_Tokenizer.LParen then
                  Fail_Tok (T, TM_Expected_LParen_After_Eml);
                  return null;
               end if;
               Advance;
               declare
                  Left : constant Node_Access := Parse_S;
               begin
                  if Result.Had_Error then
                     return null;
                  end if;
                  if At_End or else Peek.Kind /= Teml_Tokenizer.Comma then
                     Fail_Tok
                       ((if At_End then T else Peek), TM_Expected_Comma);
                     return null;
                  end if;
                  Advance;
                  declare
                     Right : constant Node_Access := Parse_S;
                  begin
                     if Result.Had_Error then
                        return null;
                     end if;
                     if At_End or else Peek.Kind /= Teml_Tokenizer.RParen then
                        Fail_Tok
                          ((if At_End then T else Peek), TM_Expected_RParen);
                        return null;
                     end if;
                     Advance;
                     return Make_Eml (Left, Right, "eml");
                  end;
               end;
            else
               Fail_Tok
                 (T,
                  TM_Unexpected_Token,
                  Teml_Tokenizer.Kind_Name (T.Kind));
               return null;
            end if;
         end;
      end Parse_S;

   begin
      if Tokens'Length = 0 then
         Result.Had_Error := True;
         Result.Error_Id := TM_Unexpected_EOI;
         Result.Error_Line := 1;
         Result.Error_Col := 1;
         return Result;
      end if;

      Result.Root := Parse_S;
      if Result.Had_Error then
         return Result;
      end if;

      if not At_End then
         Fail_Tok (Peek, TM_Unexpected_After_Expr);
         Result.Root := null;
      end if;

      return Result;
   end Parse;

end Teml_Parser;
