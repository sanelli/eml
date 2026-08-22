with Ada.Command_Line;
with Ada.Streams;
with Ada.Strings.Unbounded;

package Eml.CLI is

   package US renames Ada.Strings.Unbounded;

   type Arg_Array is array (Positive range <>) of US.Unbounded_String;

   function Run (Args : Arg_Array) return Ada.Command_Line.Exit_Status;
   --  Run with an explicit argument vector (no program name).

   function Run
     (Args       : Arg_Array;
      Stdin_Text : String) return Ada.Command_Line.Exit_Status;
   --  Test hook: text stdin when --input is omitted.

   function Run
     (Args       : Arg_Array;
      Stdin_Data : Ada.Streams.Stream_Element_Array)
      return Ada.Command_Line.Exit_Status;
   --  Test hook: binary stdin for beml when --input is omitted.

   procedure Run;
   --  Run using Ada.Command_Line arguments and set the process exit status.

end Eml.CLI;
