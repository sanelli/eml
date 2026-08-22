with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Expr_Lower;
with Expr_Parser;
with Expr_Tokenizer;
with IR_Eml;

package body Expr_Lower_Tests is

   use Ada.Strings.Unbounded;
   use IR_Eml;

   function Lower_Expr (Source : String) return IR_Eml.Node_Access is
      Tok    : constant Expr_Tokenizer.Tokenize_Result :=
        Expr_Tokenizer.Tokenize (Source);
      Parsed : constant Expr_Parser.Parse_Result :=
        Expr_Parser.Parse (Tok.Tokens.all);
   begin
      return Expr_Lower.Lower (Parsed.Root);
   end Lower_Expr;

   function Opcode_String (Ops : Opcode_Array) return String is
      Buffer : Unbounded_String := Null_Unbounded_String;
   begin
      for I in Ops'Range loop
         if Length (Buffer) > 0 then
            Append (Buffer, ",");
         end if;
         case Ops (I) is
            when One => Append (Buffer, "ONE");
            when Eml => Append (Buffer, "EML");
         end case;
      end loop;
      return To_String (Buffer);
   end Opcode_String;

   function Stack_OK (Ops : Opcode_Array) return Boolean is
      Depth : Natural := 0;
   begin
      for Op of Ops loop
         case Op is
            when One =>
               Depth := Depth + 1;
            when Eml =>
               if Depth < 2 then
                  return False;
               end if;
               Depth := Depth - 1;
         end case;
      end loop;
      return Depth = 1;
   end Stack_OK;

   procedure Run (Failed : in out Boolean) is

      procedure Require (Cond : Boolean; Message : String) is
      begin
         if not Cond then
            Failed := True;
            Ada.Text_IO.Put_Line ("FAIL: " & Message);
         end if;
      end Require;

   begin
      declare
         Ops : constant Opcode_Array_Access := Flatten (Lower_Expr ("1"));
      begin
         Require
           (Ops'Length = 1 and then Ops (1) = One,
            "lower-1: single one");
      end;

      declare
         Ops : constant Opcode_Array_Access := Flatten (Lower_Expr ("e"));
      begin
         Require
           (Opcode_String (Ops.all) = "ONE,ONE,EML",
            "lower-e: opcodes");
      end;

      declare
         Ops : constant Opcode_Array_Access := Flatten (Lower_Expr ("log(1)"));
      begin
         Require
           (Opcode_String (Ops.all) = "ONE,ONE,ONE,EML,ONE,EML,EML",
            "lower-log1: ln paper rpn");
      end;

      declare
         A : constant Opcode_Array_Access := Flatten (Lower_Expr ("+1"));
         B : constant Opcode_Array_Access := Flatten (Lower_Expr ("1"));
      begin
         Require
           (Opcode_String (A.all) = Opcode_String (B.all),
            "lower-uplus: identity");
      end;

      declare
         Ops : constant Opcode_Array_Access := Flatten (Lower_Expr ("1-1"));
      begin
         Require (Stack_OK (Ops.all), "lower-sub: stack");
         Require
           (Ada.Strings.Fixed.Index (Opcode_String (Ops.all), "EML") > 0,
            "lower-sub: has eml");
      end;

      declare
         Ops : constant Opcode_Array_Access := Flatten (Lower_Expr ("1+1"));
      begin
         Require (Stack_OK (Ops.all), "lower-add: stack");
      end;

      declare
         Ops : constant Opcode_Array_Access := Flatten (Lower_Expr ("1*1"));
      begin
         Require (Stack_OK (Ops.all), "lower-mul: stack");
      end;

      declare
         Ops : constant Opcode_Array_Access := Flatten (Lower_Expr ("1/1"));
      begin
         Require (Stack_OK (Ops.all), "lower-div: stack");
      end;

      declare
         Ops : constant Opcode_Array_Access := Flatten (Lower_Expr ("1^1"));
      begin
         Require (Stack_OK (Ops.all), "lower-pow: stack");
      end;

      declare
         Ops : constant Opcode_Array_Access := Flatten (Lower_Expr ("2"));
      begin
         Require (Stack_OK (Ops.all), "lower-2: stack");
         Require
           (Ada.Strings.Fixed.Count (Opcode_String (Ops.all), "ONE") >= 2,
            "lower-2: two ones");
      end;

      declare
         Ops : constant Opcode_Array_Access := Flatten (Lower_Expr ("0"));
      begin
         Require (Stack_OK (Ops.all), "lower-0: stack");
      end;

      declare
         Ops : constant Opcode_Array_Access := Flatten (Lower_Expr ("0.5"));
      begin
         Require (Stack_OK (Ops.all), "lower-half: stack");
      end;

      declare
         Ops : constant Opcode_Array_Access := Flatten (Lower_Expr ("2.25"));
      begin
         Require (Stack_OK (Ops.all), "lower-225: stack");
      end;

      declare
         Ops : constant Opcode_Array_Access :=
           Flatten (Lower_Expr ("sqrt(1)"));
      begin
         Require (Stack_OK (Ops.all), "lower-sqrt: stack");
      end;

      declare
         Ops : constant Opcode_Array_Access :=
           Flatten (Lower_Expr ("sinh(1)"));
      begin
         Require (Stack_OK (Ops.all), "lower-sinh: stack");
      end;

      declare
         Ops : constant Opcode_Array_Access := Flatten (Lower_Expr ("i"));
      begin
         Require (Stack_OK (Ops.all), "lower-i: stack");
      end;

      declare
         Ops : constant Opcode_Array_Access := Flatten (Lower_Expr ("pi"));
      begin
         Require (Stack_OK (Ops.all), "lower-pi: stack");
      end;

      declare
         A : constant Opcode_Array_Access := Flatten (Lower_Expr ("phi"));
         B : constant Opcode_Array_Access :=
           Flatten (Lower_Expr ("(1 + sqrt(5)) / 2"));
      begin
         Require
           (Opcode_String (A.all) = Opcode_String (B.all),
            "lower-phi: same as golden ratio");
      end;

      declare
         Ops : constant Opcode_Array_Access := Flatten (Lower_Expr ("sin(1)"));
      begin
         Require (Stack_OK (Ops.all), "lower-sin: stack");
      end;

      declare
         Ops : constant Opcode_Array_Access := Flatten (Lower_Expr ("cos(1)"));
      begin
         Require (Stack_OK (Ops.all), "lower-cos: stack");
      end;

      declare
         Ops : constant Opcode_Array_Access := Flatten (Lower_Expr ("tan(1)"));
      begin
         Require (Stack_OK (Ops.all), "lower-tan: stack");
      end;

      declare
         Ops : constant Opcode_Array_Access := Flatten (Lower_Expr ("log(e)"));
      begin
         Require (Stack_OK (Ops.all), "lower-loge: stack");
      end;
   end Run;

end Expr_Lower_Tests;
