with Ada.Command_Line;
with Ada.Strings.Unbounded;

package Eml.CLI is

   package US renames Ada.Strings.Unbounded;

   type Arg_Array is array (Positive range <>) of US.Unbounded_String;

   function Identity return String;
   --  Placeholder identity string for the executable.

   function Run (Args : Arg_Array) return Ada.Command_Line.Exit_Status;
   --  Run with an explicit argument vector (no program name).

   procedure Run;
   --  Run using Ada.Command_Line arguments and set the process exit status.

end Eml.CLI;
