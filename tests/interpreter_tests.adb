with Ada.Text_IO;

with Expr_Lower;
with Expr_Parser;
with Expr_Tokenizer;
with Interpreter;
with IR_Eml;

package body Interpreter_Tests is

   use type Interpreter.Eval_Status;

   function Strip_Image (X : Long_Float) return String is
      S : constant String := Long_Float'Image (X);
   begin
      if S'Length > 0 and then S (S'First) = ' ' then
         return S (S'First + 1 .. S'Last);
      end if;
      return S;
   end Strip_Image;

   procedure Run (Failed : in out Boolean) is

      procedure Require (Cond : Boolean; Message : String) is
      begin
         if not Cond then
            Failed := True;
            Ada.Text_IO.Put_Line ("FAIL: " & Message);
         end if;
      end Require;

      function Lower_Expr (Source : String) return IR_Eml.Node_Access is
         Tok    : constant Expr_Tokenizer.Tokenize_Result :=
           Expr_Tokenizer.Tokenize (Source);
         Parsed : constant Expr_Parser.Parse_Result :=
           Expr_Parser.Parse (Tok.Tokens.all);
      begin
         return Expr_Lower.Lower (Parsed.Root);
      end Lower_Expr;

      function Close
        (Z          : Interpreter.Complex;
         Re_E, Im_E : Long_Float;
         Tol        : Long_Float := 1.0E-10) return Boolean
      is
         Dr : constant Long_Float := Interpreter.Complex_Types.Re (Z) - Re_E;
         Di : constant Long_Float := Interpreter.Complex_Types.Im (Z) - Im_E;
      begin
         return (Dr * Dr + Di * Di) < Tol * Tol;
      end Close;

      function C (Re_V, Im_V : Long_Float) return Interpreter.Complex is
        (Interpreter.Complex_Types.Compose_From_Cartesian (Re_V, Im_V));

      Zero : constant Interpreter.Complex := C (0.0, 0.0);
      OneC : constant Interpreter.Complex := C (1.0, 0.0);
      I_C  : constant Interpreter.Complex := C (0.0, 1.0);
      MI_C : constant Interpreter.Complex := C (0.0, -1.0);
      A_C  : constant Interpreter.Complex := C (2.0, 3.0);
      B_C  : constant Interpreter.Complex := C (2.0, -3.0);
      Tiny : constant Interpreter.Complex := C (5.0, 1.0E-13);

   begin
      Require (Interpreter.Format_Complex (Zero) = "0", "format-0");
      Require
        (Interpreter.Format_Complex (OneC) = Strip_Image (1.0), "format-1");
      Require (Interpreter.Format_Complex (I_C) = "i", "format-i");
      Require (Interpreter.Format_Complex (MI_C) = "-i", "format-minus-i");
      Require
        (Interpreter.Format_Complex (A_C) =
           Strip_Image (2.0) & " + " & Strip_Image (3.0) & " i",
         "format-2+3i");
      Require
        (Interpreter.Format_Complex (B_C) =
           Strip_Image (2.0) & " - " & Strip_Image (3.0) & " i",
         "format-2-3i");
      Require
        (Interpreter.Format_Complex (Tiny) = Strip_Image (5.0),
         "format-omit-tiny-im");

      declare
         Ops : constant IR_Eml.Opcode_Array := [IR_Eml.One];
         R   : constant Interpreter.Eval_Result := Interpreter.Evaluate (Ops);
      begin
         Require (R.Status = Interpreter.Ok, "eval-one: status");
         Require (Close (R.Value, 1.0, 0.0), "eval-one: value");
      end;

      declare
         Ops : constant IR_Eml.Opcode_Array :=
           [IR_Eml.One, IR_Eml.One, IR_Eml.Eml];
         R   : constant Interpreter.Eval_Result := Interpreter.Evaluate (Ops);
      begin
         Require (R.Status = Interpreter.Ok, "eval-e: status");
         Require
           (Close (R.Value, 2.718281828459045, 0.0, 1.0E-9),
            "eval-e: value");
      end;

      declare
         R : constant Interpreter.Eval_Result :=
           Interpreter.Evaluate (Lower_Expr ("e^(i*pi)+1"));
      begin
         Require (R.Status = Interpreter.Ok, "eval-euler: status");
         Require (Close (R.Value, 0.0, 0.0, 1.0E-9), "eval-euler: ~0");
         Require
           (Interpreter.Format_Complex (R.Value) = "0", "eval-euler: format");
      end;

      declare
         R : constant Interpreter.Eval_Result :=
           Interpreter.Evaluate (Lower_Expr ("i"));
      begin
         Require (R.Status = Interpreter.Ok, "eval-i: status");
         Require (Close (R.Value, 0.0, 1.0, 1.0E-9), "eval-i: value");
         Require
           (Interpreter.Format_Complex (R.Value) = "i", "eval-i: format");
      end;

      declare
         Empty : IR_Eml.Opcode_Array (1 .. 0);
         R     : constant Interpreter.Eval_Result :=
           Interpreter.Evaluate (Empty);
      begin
         Require (R.Status = Interpreter.Stack_Not_Single, "eval-empty");
      end;

      declare
         Ops : constant IR_Eml.Opcode_Array := [IR_Eml.One, IR_Eml.One];
         R   : constant Interpreter.Eval_Result := Interpreter.Evaluate (Ops);
      begin
         Require (R.Status = Interpreter.Stack_Not_Single, "eval-leftover");
      end;

      declare
         Ops : constant IR_Eml.Opcode_Array := [IR_Eml.Eml];
         R   : constant Interpreter.Eval_Result := Interpreter.Evaluate (Ops);
      begin
         Require
           (R.Status = Interpreter.Stack_Underflow,
            "eval-underflow-eml");
      end;

      declare
         Ops : constant IR_Eml.Opcode_Array := [IR_Eml.One, IR_Eml.Eml];
         R   : constant Interpreter.Eval_Result := Interpreter.Evaluate (Ops);
      begin
         Require
           (R.Status = Interpreter.Stack_Underflow,
            "eval-underflow-one-eml");
      end;

      declare
         R : constant Interpreter.Eval_Result :=
           Interpreter.Evaluate (Lower_Expr ("log(0)"));
      begin
         Require (R.Status = Interpreter.Eval_Numeric_Error, "eval-log0");
      end;
   end Run;

end Interpreter_Tests;
