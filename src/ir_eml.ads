--  Shared IR EML tree and stack-machine encodings (.eml text, .beml binary).
with Ada.Calendar;
with Ada.Streams;
with Ada.Strings.Unbounded;

package IR_Eml is

   type Node_Kind is (One_Node, Eml_Node);

   type Node;
   type Node_Access is access Node;

   type Node is record
      Kind    : Node_Kind;
      Comment : Ada.Strings.Unbounded.Unbounded_String;
      Left    : Node_Access := null;
      Right   : Node_Access := null;
   end record;

   type Opcode is (One, Eml);

   type Opcode_Array is array (Positive range <>) of Opcode;

   type Opcode_Array_Access is access Opcode_Array;

   type Dump_Meta is record
      Source_Path : Ada.Strings.Unbounded.Unbounded_String;
      Version     : Ada.Strings.Unbounded.Unbounded_String;
      Compiled_At : Ada.Calendar.Time := Ada.Calendar.Time_Of (1980, 1, 1);
   end record;

   type Output_Format is (Eml_Text, Beml_Binary);

   function Make_One (Comment : String := "") return Node_Access;

   function Make_Eml
     (Left, Right : Node_Access; Comment : String := "") return Node_Access;

   function Flatten (Root : Node_Access) return Opcode_Array_Access;
   --  Post-order ONE/EML sequence. Null root yields empty array.

   function Count_Opcodes (Root : Node_Access) return Natural;

   function Format_Eml (Root : Node_Access; Meta : Dump_Meta) return String;

   function Format_Beml
     (Root : Node_Access; Meta : Dump_Meta)
      return Ada.Streams.Stream_Element_Array;

   procedure Write_Eml_To_File
     (Root : Node_Access; Meta : Dump_Meta; Path : String);

   procedure Write_Eml_To_Stdout (Root : Node_Access; Meta : Dump_Meta);

   procedure Write_Beml_To_File
     (Root : Node_Access; Meta : Dump_Meta; Path : String);

   procedure Write_Beml_To_Stdout (Root : Node_Access; Meta : Dump_Meta);

   function UTC_Image (T : Ada.Calendar.Time) return String;
   --  YYYY-MM-DD HH:MM:SS UTC from T using Time_Zone => 0.

   procedure UTC_Components
     (T     : Ada.Calendar.Time;
      Year  : out Ada.Calendar.Year_Number;
      Month : out Ada.Calendar.Month_Number;
      Day   : out Ada.Calendar.Day_Number;
      Hour  : out Natural;
      Minute : out Natural;
      Second : out Natural);

end IR_Eml;
