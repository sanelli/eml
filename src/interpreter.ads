--  In-process EML interpreter: ONE/EML stack over Long_Float complexes.
with Ada.Numerics.Generic_Complex_Types;
pragma Elaborate_All (Ada.Numerics.Generic_Complex_Types);
with Ada.Numerics.Generic_Complex_Elementary_Functions;
pragma Elaborate_All (Ada.Numerics.
  Generic_Complex_Elementary_Functions);

with IR_Eml;

package Interpreter is

   package Complex_Types is new
     Ada.Numerics.Generic_Complex_Types (Long_Float);
   package Complex_Fns is new
     Ada.Numerics.Generic_Complex_Elementary_Functions (Complex_Types);

   subtype Complex is Complex_Types.Complex;

   Eps : constant Long_Float := 1.0E-12;

   function Format_Complex (Z : Complex) return String;
   --  Compact one-line printer.

   type Eval_Status is
     (Ok, Stack_Underflow, Stack_Not_Single, Eval_Numeric_Error);

   type Eval_Result is record
      Status : Eval_Status := Ok;
      Value  : Complex := Complex_Types.Compose_From_Cartesian (0.0, 0.0);
      Index  : Natural := 0;
      --  1-based opcode index when Status /= Ok; 0 if no current instruction.
   end record;

   function Evaluate (Ops : IR_Eml.Opcode_Array) return Eval_Result;
   function Evaluate (Ops : IR_Eml.Opcode_Array_Access) return Eval_Result;
   function Evaluate (Root : IR_Eml.Node_Access) return Eval_Result;
   --  Flatten Root then evaluate. Null root is treated as empty program.

end Interpreter;
