with Ada.Calendar.Formatting;
with Ada.Streams.Stream_IO;
with Ada.Text_IO;
with Interfaces;

package body IR_Eml is

   use Ada.Calendar;
   use Ada.Calendar.Formatting;
   use Ada.Strings.Unbounded;
   use Ada.Streams;
   use Interfaces;

   Beml_Magic : constant Stream_Element_Array :=
     [Stream_Element'Val (16#42#),
      Stream_Element'Val (16#45#),
      Stream_Element'Val (16#4D#),
      Stream_Element'Val (16#4C#)];

   Beml_Version : constant Stream_Element := Stream_Element'Val (1);

   function Make_One (Comment : String := "") return Node_Access is
      N : constant Node_Access := new Node;
   begin
      N.Kind := One_Node;
      N.Comment := To_Unbounded_String (Comment);
      return N;
   end Make_One;

   function Make_Eml
     (Left, Right : Node_Access; Comment : String := "")
      return Node_Access
   is
      N : constant Node_Access := new Node;
   begin
      N.Kind := Eml_Node;
      N.Comment := To_Unbounded_String (Comment);
      N.Left := Left;
      N.Right := Right;
      return N;
   end Make_Eml;

   procedure Flatten_Rec
     (Root : Node_Access;
      Ops  : in out Opcode_Array;
      Idx  : in out Natural)
   is
   begin
      if Root = null then
         return;
      end if;
      case Root.Kind is
         when One_Node =>
            Idx := Idx + 1;
            Ops (Idx) := One;
         when Eml_Node =>
            Flatten_Rec (Root.Left, Ops, Idx);
            Flatten_Rec (Root.Right, Ops, Idx);
            Idx := Idx + 1;
            Ops (Idx) := Eml;
      end case;
   end Flatten_Rec;

   function Count_Opcodes (Root : Node_Access) return Natural is
      function Rec (N : Node_Access) return Natural is
      begin
         if N = null then
            return 0;
         end if;
         case N.Kind is
            when One_Node =>
               return 1;
            when Eml_Node =>
               return Rec (N.Left) + Rec (N.Right) + 1;
         end case;
      end Rec;
   begin
      return Rec (Root);
   end Count_Opcodes;

   function Flatten (Root : Node_Access) return Opcode_Array_Access is
      Count : constant Natural := Count_Opcodes (Root);
      Ops   : Opcode_Array (1 .. (if Count = 0 then 1 else Count));
      Idx   : Natural := 0;
   begin
      if Count = 0 then
         return new Opcode_Array (1 .. 0);
      end if;
      Flatten_Rec (Root, Ops, Idx);
      return new Opcode_Array'(Ops);
   end Flatten;

   function UTC_Image (T : Time) return String is
   begin
      return Image (T, Time_Zone => 0) & " UTC";
   end UTC_Image;

   procedure UTC_Components
     (T      : Time;
      Year   : out Year_Number;
      Month  : out Month_Number;
      Day    : out Day_Number;
      Hour   : out Natural;
      Minute : out Natural;
      Second : out Natural)
   is
      Img : constant String := Image (T, Time_Zone => 0);
   begin
      Year := Year_Number'Value (Img (Img'First .. Img'First + 3));
      Month := Month_Number'Value (Img (Img'First + 5 .. Img'First + 6));
      Day := Day_Number'Value (Img (Img'First + 8 .. Img'First + 9));
      Hour := Natural'Value (Img (Img'First + 11 .. Img'First + 12));
      Minute := Natural'Value (Img (Img'First + 14 .. Img'First + 15));
      Second := Natural'Value (Img (Img'First + 17 .. Img'First + 18));
   end UTC_Components;

   procedure Append_Line
     (Buffer : in out Unbounded_String; Line : String)
   is
   begin
      if Length (Buffer) > 0 then
         Append (Buffer, ASCII.LF);
      end if;
      Append (Buffer, Line);
   end Append_Line;

   procedure Format_Eml_Rec
     (N      : Node_Access;
      Buffer : in out Unbounded_String)
   is
   begin
      if N = null then
         return;
      end if;
      case N.Kind is
         when One_Node =>
            Append_Line (Buffer, "ONE");
         when Eml_Node =>
            Format_Eml_Rec (N.Left, Buffer);
            Format_Eml_Rec (N.Right, Buffer);
            declare
               Line : Unbounded_String := To_Unbounded_String ("EML");
            begin
               if Length (N.Comment) > 0 then
                  Append (Line, "  -- ");
                  Append (Line, N.Comment);
               end if;
               Append_Line (Buffer, To_String (Line));
            end;
      end case;
   end Format_Eml_Rec;

   function Format_Eml (Root : Node_Access; Meta : Dump_Meta) return String is
      Buffer : Unbounded_String := Null_Unbounded_String;
   begin
      Append_Line (Buffer, "-- Source: " & To_String (Meta.Source_Path));
      Append_Line (Buffer, "-- Compiler: eml");
      Append_Line (Buffer, "-- Version: " & To_String (Meta.Version));
      Append_Line (Buffer, "-- Date: " & UTC_Image (Meta.Compiled_At));
      Format_Eml_Rec (Root, Buffer);
      return To_String (Buffer);
   end Format_Eml;

   function Put_U16_BE (Value : Natural) return Stream_Element_Array is
      V  : constant Unsigned_32 := Unsigned_32 (Value);
      Hi : constant Natural := Natural (Shift_Right (V, 8) mod 256);
      Lo : constant Natural := Natural (V mod 256);
   begin
      return
        [Stream_Element'Val (Hi),
         Stream_Element'Val (Lo)];
   end Put_U16_BE;

   function Put_U32_BE (Value : Natural) return Stream_Element_Array is
      V  : constant Unsigned_32 := Unsigned_32 (Value);
      B1 : constant Natural := Natural (Shift_Right (V, 24) mod 256);
      B2 : constant Natural := Natural (Shift_Right (V, 16) mod 256);
      B3 : constant Natural := Natural (Shift_Right (V, 8) mod 256);
      B4 : constant Natural := Natural (V mod 256);
   begin
      return
        [Stream_Element'Val (B1),
         Stream_Element'Val (B2),
         Stream_Element'Val (B3),
         Stream_Element'Val (B4)];
   end Put_U32_BE;

   function Format_Beml
     (Root : Node_Access; Meta : Dump_Meta) return Stream_Element_Array
   is
      Ops      : constant Opcode_Array_Access := Flatten (Root);
      Count    : constant Natural :=
        (if Ops = null then 0 else Ops'Length);
      Yr       : Year_Number;
      Mo       : Month_Number;
      Dy       : Day_Number;
      Hr       : Natural;
      Mi       : Natural;
      Se       : Natural;
      Header   : Stream_Element_Array (1 .. 16);
      Code_Len : constant Natural := (Count + 7) / 8;
      Code     : Stream_Element_Array
        (1 .. Stream_Element_Offset
               (if Code_Len = 0 then 1 else Code_Len));
      Bit_Pos  : Natural := 0;
      Byte_Idx : Natural := 1;
      Current  : Stream_Element := Stream_Element'Val (0);
      Result   : Stream_Element_Array
        (1 .. Stream_Element_Offset (Header'Length + Code'Length));
   begin
      UTC_Components (Meta.Compiled_At, Yr, Mo, Dy, Hr, Mi, Se);

      Header (1 .. 4) := Beml_Magic;
      Header (5) := Beml_Version;
      Header (6 .. 7) := Put_U16_BE (Natural (Yr));
      Header (8) := Stream_Element'Val (Natural (Mo));
      Header (9) := Stream_Element'Val (Natural (Dy));
      Header (10) := Stream_Element'Val (Hr);
      Header (11) := Stream_Element'Val (Mi);
      Header (12) := Stream_Element'Val (Se);
      Header (13 .. 16) := Put_U32_BE (Count);

      if Count > 0 then
         for I in Ops'Range loop
            if Ops (I) = One then
               declare
                  Mask : constant Natural :=
                    Natural
                      (Shift_Left
                         (Unsigned_32 (1),
                          7 - (Bit_Pos mod 8)));
               begin
                  Current :=
                    Stream_Element'Val (Natural (Current) + Mask);
               end;
            end if;
            Bit_Pos := Bit_Pos + 1;
            if Bit_Pos mod 8 = 0 then
               Code (Stream_Element_Offset (Byte_Idx)) := Current;
               Byte_Idx := Byte_Idx + 1;
               Current := Stream_Element'Val (0);
            end if;
         end loop;
         if Bit_Pos mod 8 /= 0 then
            Code (Stream_Element_Offset (Byte_Idx)) := Current;
         end if;
      end if;

      Result (1 .. Header'Length) := Header;
      if Code'Length > 0 then
         Result (Header'Length + 1 .. Result'Last) := Code;
      end if;
      return Result;
   end Format_Beml;

   procedure Write_Eml_To_File
     (Root : Node_Access; Meta : Dump_Meta; Path : String)
   is
      File : Ada.Text_IO.File_Type;
      Text : constant String := Format_Eml (Root, Meta);
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put (File, Text);
      Ada.Text_IO.Close (File);
   end Write_Eml_To_File;

   procedure Write_Eml_To_Stdout (Root : Node_Access; Meta : Dump_Meta) is
      Text : constant String := Format_Eml (Root, Meta);
   begin
      Ada.Text_IO.Put (Ada.Text_IO.Standard_Output, Text);
      if Text'Length = 0 or else Text (Text'Last) /= ASCII.LF then
         Ada.Text_IO.New_Line (Ada.Text_IO.Standard_Output);
      end if;
   end Write_Eml_To_Stdout;

   procedure Write_Beml_To_File
     (Root : Node_Access; Meta : Dump_Meta; Path : String)
   is
      File : Stream_IO.File_Type;
      Data : constant Stream_Element_Array := Format_Beml (Root, Meta);
   begin
      Stream_IO.Create (File, Stream_IO.Out_File, Path);
      Stream_IO.Write (File, Data);
      Stream_IO.Close (File);
   end Write_Beml_To_File;

   procedure Write_Beml_To_Stdout (Root : Node_Access; Meta : Dump_Meta) is
      Data : constant Stream_Element_Array := Format_Beml (Root, Meta);
   begin
      for E of Data loop
         Ada.Text_IO.Put
           (Ada.Text_IO.Standard_Output,
            Character'Val (Natural (E)));
      end loop;
   end Write_Beml_To_Stdout;

end IR_Eml;
