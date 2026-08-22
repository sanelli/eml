with Ada.Calendar;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Streams;
with Ada.Text_IO;
with IR_Eml;

package body IR_Eml_Tests is

   use Ada.Calendar;
   use Ada.Strings.Unbounded;
   use Ada.Streams;
   use IR_Eml;

   function Test_Meta return Dump_Meta is
   begin
      return
        (Source_Path => To_Unbounded_String ("e.teml"),
         Version     => To_Unbounded_String ("0.1.0-dev"),
         Compiled_At => Time_Of (2026, 8, 22, 9 * 3600.0));
   end Test_Meta;

   function E_Tree return Node_Access is
   begin
      return Make_Eml (Make_One, Make_One, "e");
   end E_Tree;

   function Stack_Depth (Ops : Opcode_Array) return Natural is
      Depth : Natural := 0;
   begin
      for Op of Ops loop
         case Op is
            when One =>
               Depth := Depth + 1;
            when Eml =>
               if Depth < 2 then
                  return 0;
               end if;
               Depth := Depth - 1;
         end case;
      end loop;
      return Depth;
   end Stack_Depth;

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
         Text : constant String := Format_Eml (E_Tree, Test_Meta);
      begin
         Require
           (Ada.Strings.Fixed.Index (Text, "-- Source: e.teml") > 0,
            "ir-eml: source header");
         Require
           (Ada.Strings.Fixed.Index (Text, "-- Version: 0.1.0-dev") > 0,
            "ir-eml: version header");
         Require
           (Ada.Strings.Fixed.Index
              (Text, "-- Date: " & UTC_Image (Test_Meta.Compiled_At))
            > 0,
            "ir-eml: utc date");
         Require
           (Ada.Strings.Fixed.Index (Text, "ONE" & ASCII.LF & "ONE") > 0,
            "ir-eml: bare one lines");
         Require
           (Ada.Strings.Fixed.Index (Text, "ONE  -- 1") = 0,
            "ir-eml: no one comments");
         Require
           (Ada.Strings.Fixed.Index (Text, "EML  -- e") > 0,
            "ir-eml: eml comment");
         Require
           (Ada.Strings.Fixed.Count (Text, "ONE") >= 2,
            "ir-eml: two ones");
      end;

      declare
         Ops : constant Opcode_Array_Access := Flatten (E_Tree);
      begin
         Require (Ops'Length = 3, "ir-eml: opcode count");
         Require (Ops (1) = One and then Ops (2) = One and then Ops (3) = Eml,
                  "ir-eml: opcode order");
         Require (Stack_Depth (Ops.all) = 1, "ir-eml: stack ends at depth 1");
         declare
            Ones : Natural := 0;
            Emls : Natural := 0;
         begin
            for Op of Ops.all loop
               case Op is
                  when One => Ones := Ones + 1;
                  when Eml => Emls := Emls + 1;
               end case;
            end loop;
            Require (Ones = Emls + 1, "ir-eml: one eml balance");
         end;
      end;

      declare
         Bin : constant Stream_Element_Array :=
           Format_Beml (E_Tree, Test_Meta);
         Yr  : Ada.Calendar.Year_Number;
         Mo  : Ada.Calendar.Month_Number;
         Dy  : Ada.Calendar.Day_Number;
         Hr  : Natural;
         Mi  : Natural;
         Se  : Natural;
      begin
         UTC_Components (Test_Meta.Compiled_At, Yr, Mo, Dy, Hr, Mi, Se);
         Require (Bin'Length = 17, "ir-beml: total length");
         Require
           (Bin (1) = Stream_Element'Val (16#42#)
            and then Bin (2) = Stream_Element'Val (16#45#)
            and then Bin (3) = Stream_Element'Val (16#4D#)
            and then Bin (4) = Stream_Element'Val (16#4C#),
            "ir-beml: magic");
         Require (Bin (5) = Stream_Element'Val (1), "ir-beml: version");
         Require
           (Bin (6) = Stream_Element'Val (16#07#)
            and then Bin (7) = Stream_Element'Val (16#EA#),
            "ir-beml: year be");
         Require
           (Bin (8) = Stream_Element'Val (8)
            and then Bin (9) = Stream_Element'Val (22),
            "ir-beml: month day");
         Require
           (Bin (10) = Stream_Element'Val (Hr)
            and then Bin (11) = Stream_Element'Val (Mi)
            and then Bin (12) = Stream_Element'Val (Se),
            "ir-beml: time");
         Require
           (Bin (13) = Stream_Element'Val (0)
            and then Bin (14) = Stream_Element'Val (0)
            and then Bin (15) = Stream_Element'Val (0)
            and then Bin (16) = Stream_Element'Val (3),
            "ir-beml: count be");
         Require
           (Bin (17) = Stream_Element'Val (16#C0#),
            "ir-beml: code bits");
      end;

      declare
         Five : constant Node_Access :=
           Make_Eml
             (Make_Eml (Make_One, Make_One, "a"),
              Make_One,
              "b");
         Bin  : constant Stream_Element_Array := Format_Beml (Five, Test_Meta);
      begin
         Require (Count_Opcodes (Five) = 5, "ir-beml: five count");
         Require (Bin'Length = 16 + 1, "ir-beml: five byte length");
         Require
           (Bin (17) = Stream_Element'Val (16#D0#),
            "ir-beml: five padded byte");
      end;
   end Run;

end IR_Eml_Tests;
