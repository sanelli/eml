with Ada.Numerics;
with Ada.Unchecked_Conversion;
with Interfaces;

package body Interpreter is

   pragma Suppress (Validity_Check);

   use Complex_Types;
   use Complex_Fns;

   pragma Compile_Time_Error
     (Long_Float'Size /= 64,
      "Interpreter requires 64-bit Long_Float");

   function Bits_To_LF is new Ada.Unchecked_Conversion
     (Interfaces.Unsigned_64, Long_Float);

   --  IEEE 754 binary64 infinities. Soft Exp/Log use these so Peano-lowered
   --  trees (Zero, Neg, i, pi) can pass through log(0) intermediates. A
   --  non-finite final value is still Eval_Numeric_Error (e.g. log(0)).
   Pos_Inf : constant Long_Float :=
     Bits_To_LF (16#7FF0_0000_0000_0000#);
   Neg_Inf : constant Long_Float :=
     Bits_To_LF (16#FFF0_0000_0000_0000#);

   Exp_Clamp : constant Long_Float := 700.0;
   Log_Tiny  : constant Long_Float := 1.0E-300;

   type C2 is record
      Re : Long_Float := 0.0;
      Im : Long_Float := 0.0;
   end record;

   function Is_Finite (X : Long_Float) return Boolean is
     (X <= Long_Float'Last and then X >= -Long_Float'Last);

   function Is_Finite_C2 (Z : C2) return Boolean is
     (Is_Finite (Z.Re) and then Is_Finite (Z.Im));

   function Mag2 (Z : C2) return Long_Float is
   begin
      if not Is_Finite_C2 (Z) then
         return Pos_Inf;
      end if;
      declare
         S : constant Long_Float := Z.Re * Z.Re + Z.Im * Z.Im;
      begin
         if not Is_Finite (S) then
            return Pos_Inf;
         end if;
         return S;
      end;
   end Mag2;

   function Soft_Sub_R (A, B : Long_Float) return Long_Float is
      A_Fin : constant Boolean := Is_Finite (A);
      B_Fin : constant Boolean := Is_Finite (B);
   begin
      if A_Fin and then B_Fin then
         return A - B;
      elsif not A_Fin and then not B_Fin then
         if (A > 0.0) = (B > 0.0) then
            return 0.0;
         end if;
         return A;
      elsif not A_Fin then
         return A;
      elsif B > 0.0 then
         return Neg_Inf;
      else
         return Pos_Inf;
      end if;
   end Soft_Sub_R;

   function Soft_Log (Z : C2) return C2 is
      M2 : constant Long_Float := Mag2 (Z);
      W  : Complex;
   begin
      if not Is_Finite (M2) then
         return (Re => Pos_Inf, Im => 0.0);
      elsif abs (Z.Re) < Log_Tiny and then abs (Z.Im) < Log_Tiny then
         return (Re => Neg_Inf, Im => 0.0);
      end if;
      W := Compose_From_Cartesian (Z.Re, Z.Im);
      W := Log (W);
      return (Re => Re (W), Im => Im (W));
   exception
      when Ada.Numerics.Argument_Error | Constraint_Error =>
         if abs (Z.Re) < Log_Tiny and then abs (Z.Im) < Log_Tiny then
            return (Re => Neg_Inf, Im => 0.0);
         end if;
         return (Re => Pos_Inf, Im => 0.0);
   end Soft_Log;

   function Soft_Exp (Z : C2) return C2 is
      W : Complex;
   begin
      if not Is_Finite (Z.Re) then
         if Z.Re > 0.0 then
            return (Re => Pos_Inf, Im => 0.0);
         elsif Z.Re < 0.0 then
            return (Re => 0.0, Im => 0.0);
         end if;
         return (Re => Pos_Inf, Im => 0.0);
      elsif Z.Re > Exp_Clamp then
         return (Re => Pos_Inf, Im => 0.0);
      elsif Z.Re < -Exp_Clamp then
         return (Re => 0.0, Im => 0.0);
      end if;
      W := Compose_From_Cartesian (Z.Re, Z.Im);
      W := Exp (W);
      return (Re => Re (W), Im => Im (W));
   exception
      when Constraint_Error =>
         if Z.Re > 0.0 then
            return (Re => Pos_Inf, Im => 0.0);
         end if;
         return (Re => 0.0, Im => 0.0);
   end Soft_Exp;

   function Soft_Eml (X, Y : C2) return C2 is
      Ex : constant C2 := Soft_Exp (X);
      Ln : constant C2 := Soft_Log (Y);
   begin
      return
        (Re => Soft_Sub_R (Ex.Re, Ln.Re),
         Im => Soft_Sub_R (Ex.Im, Ln.Im));
   end Soft_Eml;

   function Strip_Leading_Space (S : String) return String is
   begin
      if S'Length > 0 and then S (S'First) = ' ' then
         return S (S'First + 1 .. S'Last);
      end if;
      return S;
   end Strip_Leading_Space;

   function Image_Of (X : Long_Float) return String is
     (Strip_Leading_Space (Long_Float'Image (X)));

   function Near_Zero (X : Long_Float) return Boolean is
     (abs (X) < Eps);

   function Near_One (X : Long_Float) return Boolean is
     (abs (abs (X) - 1.0) < Eps);

   function Format_Complex (Z : Complex) return String is
      R : constant Long_Float := Re (Z);
      I : constant Long_Float := Im (Z);
   begin
      if Near_Zero (R) and then Near_Zero (I) then
         return "0";
      elsif Near_Zero (I) then
         return Image_Of (R);
      elsif Near_Zero (R) and then Near_One (I) and then I > 0.0 then
         return "i";
      elsif Near_Zero (R) and then Near_One (I) and then I < 0.0 then
         return "-i";
      elsif Near_Zero (R) then
         return Image_Of (I) & " i";
      elsif I > 0.0 then
         return Image_Of (R) & " + " & Image_Of (I) & " i";
      else
         return Image_Of (R) & " - " & Image_Of (abs (I)) & " i";
      end if;
   end Format_Complex;

   function Evaluate (Ops : IR_Eml.Opcode_Array) return Eval_Result is
      Stack  : array (1 .. Ops'Length + 1) of C2;
      Top    : Natural := 0;
      Result : Eval_Result;
   begin
      if Ops'Length = 0 then
         Result.Status := Stack_Not_Single;
         Result.Index := 0;
         return Result;
      end if;

      for I in Ops'Range loop
         case Ops (I) is
            when IR_Eml.One =>
               Top := Top + 1;
               Stack (Top) := (Re => 1.0, Im => 0.0);

            when IR_Eml.Eml =>
               if Top < 2 then
                  Result.Status := Stack_Underflow;
                  Result.Index := I;
                  return Result;
               end if;
               declare
                  Y : constant C2 := Stack (Top);
                  X : constant C2 := Stack (Top - 1);
               begin
                  Top := Top - 2;
                  begin
                     Top := Top + 1;
                     Stack (Top) := Soft_Eml (X, Y);
                  exception
                     when Ada.Numerics.Argument_Error | Constraint_Error =>
                        Result.Status := Eval_Numeric_Error;
                        Result.Index := I;
                        return Result;
                  end;
               end;
         end case;
      end loop;

      if Top /= 1 then
         Result.Status := Stack_Not_Single;
         Result.Index := 0;
         return Result;
      end if;

      if not Is_Finite_C2 (Stack (1)) then
         Result.Status := Eval_Numeric_Error;
         Result.Index := Ops'Last;
         return Result;
      end if;

      Result.Status := Ok;
      Result.Value :=
        Compose_From_Cartesian (Stack (1).Re, Stack (1).Im);
      Result.Index := 0;
      return Result;
   end Evaluate;

   function Evaluate (Ops : IR_Eml.Opcode_Array_Access) return Eval_Result is
      use type IR_Eml.Opcode_Array_Access;
      Empty : Eval_Result;
   begin
      if Ops = null then
         Empty.Status := Stack_Not_Single;
         return Empty;
      end if;
      return Evaluate (Ops.all);
   end Evaluate;

   function Evaluate (Root : IR_Eml.Node_Access) return Eval_Result is
      Ops : constant IR_Eml.Opcode_Array_Access := IR_Eml.Flatten (Root);
   begin
      return Evaluate (Ops);
   end Evaluate;

end Interpreter;
