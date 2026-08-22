with Ada.Numerics.Big_Numbers.Big_Integers;
with Ada.Strings.Unbounded;

package body Expr_Lower is

   use Ada.Numerics.Big_Numbers.Big_Integers;
   use Ada.Strings.Unbounded;
   use IR_Eml;
   use type Expr_Parser.Node_Access;

   function Exp_X (X : Node_Access) return Node_Access is
   begin
      return Make_Eml (X, Make_One, "exp");
   end Exp_X;

   function Ln_Z (Z : Node_Access) return Node_Access is
      Inner1 : constant Node_Access :=
        Make_Eml (Make_One, Z, "ln");
      Inner2 : constant Node_Access :=
        Make_Eml (Inner1, Make_One, "ln");
   begin
      return Make_Eml (Make_One, Inner2, "ln");
   end Ln_Z;

   function Sub_XY (X, Y : Node_Access) return Node_Access is
   begin
      return Make_Eml (Ln_Z (X), Exp_X (Y), "sub");
   end Sub_XY;

   function Zero return Node_Access is
   begin
      return Sub_XY (Make_One, Make_One);
   end Zero;

   function Neg_Y (Y : Node_Access) return Node_Access is
   begin
      return Sub_XY (Zero, Y);
   end Neg_Y;

   function Add_XY (X, Y : Node_Access) return Node_Access is
   begin
      return Sub_XY (X, Neg_Y (Y));
   end Add_XY;

   function Mul_XY (X, Y : Node_Access) return Node_Access is
   begin
      return Exp_X (Add_XY (Ln_Z (X), Ln_Z (Y)));
   end Mul_XY;

   function Div_XY (X, Y : Node_Access) return Node_Access is
   begin
      return Exp_X (Sub_XY (Ln_Z (X), Ln_Z (Y)));
   end Div_XY;

   function Pow_XY (X, Y : Node_Access) return Node_Access is
   begin
      return Exp_X (Mul_XY (Y, Ln_Z (X)));
   end Pow_XY;

   function Two return Node_Access is
   begin
      return Add_XY (Make_One, Make_One);
   end Two;

   function Sqrt_X (X : Node_Access) return Node_Access is
      Half : constant Node_Access := Div_XY (Make_One, Two);
   begin
      return Exp_X (Mul_XY (Half, Ln_Z (X)));
   end Sqrt_X;

   function Sinh_X (X : Node_Access) return Node_Access is
   begin
      return Div_XY
        (Sub_XY (Exp_X (X), Exp_X (Neg_Y (X))),
         Two);
   end Sinh_X;

   function Cosh_X (X : Node_Access) return Node_Access is
   begin
      return Div_XY
        (Add_XY (Exp_X (X), Exp_X (Neg_Y (X))),
         Two);
   end Cosh_X;

   function Tanh_X (X : Node_Access) return Node_Access is
   begin
      return Div_XY (Sinh_X (X), Cosh_X (X));
   end Tanh_X;

   function I_Const return Node_Access is
   begin
      return Sqrt_X (Sub_XY (Zero, Make_One));
   end I_Const;

   function Pi_Const return Node_Access is
   begin
      return Div_XY (Ln_Z (Sub_XY (Zero, Make_One)), I_Const);
   end Pi_Const;

   function Cos_X (X : Node_Access) return Node_Access is
      IX : constant Node_Access := Mul_XY (I_Const, X);
   begin
      return Div_XY
        (Add_XY (Exp_X (IX), Exp_X (Neg_Y (IX))),
         Two);
   end Cos_X;

   function Sin_X (X : Node_Access) return Node_Access is
      IX : constant Node_Access := Mul_XY (I_Const, X);
   begin
      return Div_XY
        (Sub_XY (Exp_X (IX), Exp_X (Neg_Y (IX))),
         Mul_XY (Two, I_Const));
   end Sin_X;

   function Tan_X (X : Node_Access) return Node_Access is
   begin
      return Div_XY (Sin_X (X), Cos_X (X));
   end Tan_X;

   function E_Const return Node_Access is
   begin
      return Make_Eml (Make_One, Make_One, "e");
   end E_Const;

   function Integer_Value (N : Natural) return Node_Access is
   begin
      if N = 0 then
         return Zero;
      elsif N = 1 then
         return Make_One;
      else
         return Add_XY (Integer_Value (N - 1), Make_One);
      end if;
   end Integer_Value;

   function Phi_Const return Node_Access is
   begin
      return Div_XY
        (Add_XY (Make_One, Sqrt_X (Integer_Value (5))),
         Two);
   end Phi_Const;

   function Big_Natural (N : Big_Integer) return Natural is
      Img : constant String := To_String (N);
   begin
      return Natural'Value (Img);
   end Big_Natural;

   function Trim_Image (N : Integer) return String is
      S : constant String := Integer'Image (N);
   begin
      if S (S'First) = ' ' then
         return S (S'First + 1 .. S'Last);
      end if;
      return S;
   end Trim_Image;

   function Rat_GCD (A, B : Big_Integer) return Big_Integer is
      X : Big_Integer := A;
      Y : Big_Integer := B;
   begin
      while Y /= 0 loop
         declare
            T : constant Big_Integer := X mod Y;
         begin
            X := Y;
            Y := T;
         end;
      end loop;
      return X;
   end Rat_GCD;

   procedure Parse_Rational
     (Lexeme : String; Num, Den : out Big_Integer)
   is
      Dot        : Natural := 0;
      E_Pos      : Natural := 0;
      Digit_Text : Unbounded_String := Null_Unbounded_String;
      Frac       : Natural := 1;
      Exp        : Integer := 0;
   begin
      for I in Lexeme'Range loop
         if Lexeme (I) = '.' then
            Dot := I;
         elsif Lexeme (I) = 'e' or else Lexeme (I) = 'E' then
            E_Pos := I;
            exit;
         end if;
      end loop;

      if E_Pos > 0 then
         Exp := Integer'Value (Lexeme (E_Pos + 1 .. Lexeme'Last));
         if Dot > 0 and then Dot < E_Pos then
            for I in Lexeme'First .. Dot - 1 loop
               Append (Digit_Text, Lexeme (I));
            end loop;
            for I in Dot + 1 .. E_Pos - 1 loop
               Append (Digit_Text, Lexeme (I));
               Frac := Frac * 10;
            end loop;
         else
            for I in Lexeme'First .. E_Pos - 1 loop
               if Lexeme (I) /= '.' then
                  Append (Digit_Text, Lexeme (I));
               end if;
            end loop;
         end if;
      elsif Dot > 0 then
         for I in Lexeme'First .. Dot - 1 loop
            Append (Digit_Text, Lexeme (I));
         end loop;
         for I in Dot + 1 .. Lexeme'Last loop
            Append (Digit_Text, Lexeme (I));
            Frac := Frac * 10;
         end loop;
      else
         Digit_Text := To_Unbounded_String (Lexeme);
      end if;

      Num := From_String (To_String (Digit_Text));
      Den := From_String (Trim_Image (Integer (Frac)));

      if Exp > 0 then
         for I in 1 .. Exp loop
            Num := Num * 10;
         end loop;
      elsif Exp < 0 then
         for I in 1 .. Integer (-Exp) loop
            Den := Den * 10;
         end loop;
      end if;

      declare
         G : constant Big_Integer := Rat_GCD (Num, Den);
      begin
         Num := Num / G;
         Den := Den / G;
      end;
   end Parse_Rational;

   function Lower_Number (Lexeme : String) return Node_Access is
      Num : Big_Integer;
      Den : Big_Integer;
   begin
      Parse_Rational (Lexeme, Num, Den);
      if Den = From_String ("1") then
         return Integer_Value (Big_Natural (Num));
      else
         return Div_XY
           (Integer_Value (Big_Natural (Num)),
            Integer_Value (Big_Natural (Den)));
      end if;
   end Lower_Number;

   function Lower_Call (Name : String; Arg : Node_Access) return Node_Access is
   begin
      if Name = "log" then
         return Ln_Z (Arg);
      elsif Name = "sin" then
         return Sin_X (Arg);
      elsif Name = "cos" then
         return Cos_X (Arg);
      elsif Name = "tan" then
         return Tan_X (Arg);
      elsif Name = "sqrt" then
         return Sqrt_X (Arg);
      elsif Name = "sinh" then
         return Sinh_X (Arg);
      elsif Name = "cosh" then
         return Cosh_X (Arg);
      elsif Name = "tanh" then
         return Tanh_X (Arg);
      else
         raise Program_Error with "unknown call: " & Name;
      end if;
   end Lower_Call;

   function Lower (Root : Expr_Parser.Node_Access) return Node_Access is
   begin
      if Root = null then
         return null;
      end if;

      case Root.Kind is
         when Expr_Parser.Number_Node =>
            return Lower_Number (To_String (Root.Lexeme));

         when Expr_Parser.Constant_Node =>
            declare
               Name : constant String := To_String (Root.Lexeme);
            begin
               if Name = "e" then
                  return E_Const;
               elsif Name = "i" then
                  return I_Const;
               elsif Name = "pi" then
                  return Pi_Const;
               elsif Name = "phi" then
                  return Phi_Const;
               else
                  raise Program_Error with "unknown constant: " & Name;
               end if;
            end;

         when Expr_Parser.UPlus_Node =>
            return Lower (Root.Left);

         when Expr_Parser.UMinus_Node =>
            return Neg_Y (Lower (Root.Left));

         when Expr_Parser.Add_Node =>
            return Add_XY (Lower (Root.Left), Lower (Root.Right));

         when Expr_Parser.Sub_Node =>
            return Sub_XY (Lower (Root.Left), Lower (Root.Right));

         when Expr_Parser.Mul_Node =>
            return Mul_XY (Lower (Root.Left), Lower (Root.Right));

         when Expr_Parser.Div_Node =>
            return Div_XY (Lower (Root.Left), Lower (Root.Right));

         when Expr_Parser.Pow_Node =>
            return Pow_XY (Lower (Root.Left), Lower (Root.Right));

         when Expr_Parser.Call_Node =>
            return Lower_Call (To_String (Root.Lexeme), Lower (Root.Left));
      end case;
   end Lower;

end Expr_Lower;
