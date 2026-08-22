with Ada.Strings.Unbounded;
with Ada.Text_IO;

with Expr_Preprocessor;

package body Expr_Preprocessor_Tests is

   use Ada.Strings.Unbounded;
   use Expr_Preprocessor;

   procedure Run (Failed : in out Boolean) is

      procedure Require (Cond : Boolean; Message : String) is
      begin
         if not Cond then
            Failed := True;
            Ada.Text_IO.Put_Line ("FAIL: " & Message);
         end if;
      end Require;

      function Bind (Name, Value : String) return Binding is
      begin
         return
           (Name  => To_Unbounded_String (Name),
            Value => To_Unbounded_String (Value));
      end Bind;

      function No_Bindings return Binding_Array is
         Empty : Binding_Array (1 .. 0);
      begin
         return Empty;
      end No_Bindings;

   begin
      declare
         R : constant Preprocess_Result :=
           Preprocess ("1 + 2", No_Bindings);
      begin
         Require (not R.Had_Error, "identity: ok");
         Require (To_String (R.Text) = "1 + 2", "identity: text");
         Require (R.Unused'Length = 0, "identity: unused");
      end;

      declare
         B : constant Binding_Array := [1 => Bind ("$X", "42")];
         R : constant Preprocess_Result :=
           Preprocess ("$X + $X", B);
      begin
         Require (not R.Had_Error, "repeat: ok");
         Require (To_String (R.Text) = "42 + 42", "repeat: text");
         Require (R.Unused'Length = 0, "repeat: unused");
      end;

      declare
         B : constant Binding_Array :=
           [1 => Bind ("$X", "1"), 2 => Bind ("$Y", "2")];
         R : constant Preprocess_Result :=
           Preprocess ("$X + $Y", B);
      begin
         Require (not R.Had_Error, "two-vars: ok");
         Require (To_String (R.Text) = "1 + 2", "two-vars: text");
      end;

      declare
         B : constant Binding_Array :=
           [1 => Bind ("$X", "a"), 2 => Bind ("$XX", "b")];
         R : constant Preprocess_Result :=
           Preprocess ("$XX + $X", B);
      begin
         Require (not R.Had_Error, "xx-vs-x: ok");
         Require (To_String (R.Text) = "b + a", "xx-vs-x: text");
      end;

      declare
         B : constant Binding_Array := [1 => Bind ("$X", "1+2")];
         R : constant Preprocess_Result :=
           Preprocess ("2*$X", B);
      begin
         Require (not R.Had_Error, "paste: ok");
         Require (To_String (R.Text) = "2*1+2", "paste: text");
      end;

      declare
         B : constant Binding_Array := [1 => Bind ("$X", "sin(pi)")];
         R : constant Preprocess_Result :=
           Preprocess ("f($X)", B);
      begin
         Require (not R.Had_Error, "origin: ok");
         Require (R.Origins'Length = To_String (R.Text)'Length, "origin: len");
         if R.Origins'Length >= 6 then
            for I in 4 .. 6 loop
               Require
                 (R.Origins (I).Line = 1 and then R.Origins (I).Column = 3,
                  "origin: pos-" & Positive'Image (I));
               Require
                 (R.Origins (I).From_Var,
                  "origin: from-var-" & Positive'Image (I));
               Require
                 (To_String (R.Origins (I).Var_Name) = "$X",
                  "origin: name-" & Positive'Image (I));
            end loop;
         end if;
      end;

      declare
         B : constant Binding_Array := [1 => Bind ("$X", "1")];
         R : constant Preprocess_Result :=
           Preprocess ("$X", B);
      begin
         Require (not R.Had_Error, "single: ok");
         Require (R.Origins'Length = 1, "single: origin len");
         Require (R.Origins (1).Line = 1, "single: line");
         Require (R.Origins (1).Column = 1, "single: column");
         Require (R.Origins (1).From_Var, "single: from-var");
      end;

      declare
         R : constant Preprocess_Result :=
           Preprocess ("$X", No_Bindings);
      begin
         Require (R.Had_Error, "unbound: error");
         Require (R.Unbound'Length = 1, "unbound: count");
         Require (R.Unbound (1).Line = 1, "unbound: line");
         Require (R.Unbound (1).Column = 1, "unbound: column");
         Require
           (To_String (R.Unbound (1).Var_Name) = "$X",
            "unbound: name");
      end;

      declare
         B : constant Binding_Array := [1 => Bind ("$X", "1")];
         R : constant Preprocess_Result :=
           Preprocess ("$X + $Y + $X", B);
      begin
         Require (R.Had_Error, "multi-unbound: error");
         Require (R.Unbound'Length = 1, "multi-unbound: count");
         Require (R.Unbound (1).Column = 6, "multi-unbound: column");
         Require
           (To_String (R.Unbound (1).Var_Name) = "$Y",
            "multi-unbound: name");
      end;

      declare
         R : constant Preprocess_Result :=
           Preprocess ("$X + $Y", No_Bindings);
      begin
         Require (R.Had_Error, "two-unbound: error");
         Require (R.Unbound'Length = 2, "two-unbound: count");
         Require
           (To_String (R.Unbound (1).Var_Name) = "$X",
            "two-unbound: first");
         Require
           (To_String (R.Unbound (2).Var_Name) = "$Y",
            "two-unbound: second");
      end;

      declare
         B : constant Binding_Array := [1 => Bind ("$Y", "9")];
         R : constant Preprocess_Result :=
           Preprocess ("1", B);
      begin
         Require (not R.Had_Error, "unused-bind: ok");
         Require (R.Unused'Length = 1, "unused-bind: count");
         Require
           (To_String (R.Unused (1)) = "$Y",
            "unused-bind: name");
      end;

      declare
         R : constant Preprocess_Result :=
           Preprocess ("$", No_Bindings);
      begin
         Require (not R.Had_Error, "bare-dollar: ok");
         Require (To_String (R.Text) = "$", "bare-dollar: text");
      end;

      declare
         R : constant Preprocess_Result :=
           Preprocess ("$1", No_Bindings);
      begin
         Require (not R.Had_Error, "dollar-one: ok");
         Require (To_String (R.Text) = "$1", "dollar-one: text");
      end;
   end Run;

end Expr_Preprocessor_Tests;
