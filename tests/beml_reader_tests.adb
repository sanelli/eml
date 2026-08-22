with Ada.Calendar;
with Ada.Streams;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Beml_Reader;
with Eml.Diagnostics;
with IR_Eml;

package body Beml_Reader_Tests is

   use Ada.Strings.Unbounded;
   use type IR_Eml.Opcode_Array_Access;

   procedure Run (Failed : in out Boolean) is
      procedure Require (Cond : Boolean; Msg : String) is
      begin
         if not Cond then
            Failed := True;
            Ada.Text_IO.Put_Line ("FAIL: " & Msg);
         end if;
      end Require;
   begin
      declare
         Root : constant IR_Eml.Node_Access :=
           IR_Eml.Make_Eml (IR_Eml.Make_One, IR_Eml.Make_One);
         Meta : constant IR_Eml.Dump_Meta :=
           (Source_Path => To_Unbounded_String ("t"),
            Version     => To_Unbounded_String ("0"),
            Compiled_At => Ada.Calendar.Clock);
         Data : constant Ada.Streams.Stream_Element_Array :=
           IR_Eml.Format_Beml (Root, Meta);
         Read : constant Beml_Reader.Read_Result :=
           Beml_Reader.Read_Bytes (Data);
      begin
         Require (not Read.Had_Error, "beml-read: ok");
         if Read.Had_Error then
            Ada.Text_IO.Put_Line
              ("beml-read debug Error_Id="
               & Eml.Diagnostics.Id_Image (Read.Error_Id));
         end if;
         if not Read.Had_Error then
            Require
              (Read.Opcodes /= null
               and then Read.Opcodes'Length = 3,
               "beml-read: ops");
         end if;
      end;

      declare
         Bad : constant Ada.Streams.Stream_Element_Array :=
           [Ada.Streams.Stream_Element'Val (0),
            Ada.Streams.Stream_Element'Val (0)];
         Read : constant Beml_Reader.Read_Result :=
           Beml_Reader.Read_Bytes (Bad);
      begin
         Require (Read.Had_Error, "beml-read: short");
      end;
   end Run;

end Beml_Reader_Tests;
