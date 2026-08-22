with Ada.Calendar;
with Ada.Streams.Stream_IO;
with Interfaces;

package body Beml_Reader is

   use Ada.Calendar;
   use Ada.Streams;
   use Interfaces;
   use IR_Eml;
   use Eml.Diagnostics;

   Beml_Magic : constant Stream_Element_Array :=
     [Stream_Element'Val (16#42#),
      Stream_Element'Val (16#45#),
      Stream_Element'Val (16#4D#),
      Stream_Element'Val (16#4C#)];

   function Fail
     (Id : Diagnostic_Id; Col : Positive) return Read_Result
   is
   begin
      return
        (Opcodes    => null,
         Had_Error  => True,
         Error_Id   => Id,
         Error_Line => 1,
         Error_Col  => Col);
   end Fail;

   function Get_U16_BE (Data : Stream_Element_Array; Off : Natural)
      return Natural
   is
      Hi : constant Natural := Natural (Data (Stream_Element_Offset (Off)));
      Lo : constant Natural :=
        Natural (Data (Stream_Element_Offset (Off + 1)));
   begin
      return Hi * 256 + Lo;
   end Get_U16_BE;

   function Get_U32_BE (Data : Stream_Element_Array; Off : Natural)
      return Natural
   is
      B1 : constant Natural := Natural (Data (Stream_Element_Offset (Off)));
      B2 : constant Natural :=
        Natural (Data (Stream_Element_Offset (Off + 1)));
      B3 : constant Natural :=
        Natural (Data (Stream_Element_Offset (Off + 2)));
      B4 : constant Natural :=
        Natural (Data (Stream_Element_Offset (Off + 3)));
   begin
      return
        B1 * 16_777_216 + B2 * 65_536 + B3 * 256 + B4;
   end Get_U32_BE;

   function Valid_Timestamp
     (Yr : Natural;
      Mo : Natural;
      Dy : Natural;
      Hr : Natural;
      Mi : Natural;
      Se : Natural) return Boolean
   is
      Dummy : Time;
   begin
      if Yr < Year_Number'First or else Yr > Year_Number'Last then
         return False;
      end if;
      if Mo < 1 or else Mo > 12 then
         return False;
      end if;
      if Dy < 1 or else Dy > 31 then
         return False;
      end if;
      if Hr > 23 or else Mi > 59 or else Se > 59 then
         return False;
      end if;
      Dummy :=
        Time_Of
          (Year_Number (Yr),
           Month_Number (Mo),
           Day_Number (Dy),
           Duration (Hr * 3600 + Mi * 60 + Se));
      return True;
   exception
      when others =>
         return False;
   end Valid_Timestamp;

   function Read_Bytes (Data : Stream_Element_Array) return Read_Result is
      Len : constant Natural := Natural (Data'Length);
   begin
      if Len < 16 then
         return Fail (BE_Too_Short, 1);
      end if;

      if Data (1 .. 4) /= Beml_Magic then
         return Fail (BE_Bad_Magic, 1);
      end if;

      if Data (5) /= Stream_Element'Val (1) then
         return Fail (BE_Bad_Version, 5);
      end if;

      declare
         Yr : constant Natural := Get_U16_BE (Data, 6);
         Mo : constant Natural := Natural (Data (8));
         Dy : constant Natural := Natural (Data (9));
         Hr : constant Natural := Natural (Data (10));
         Mi : constant Natural := Natural (Data (11));
         Se : constant Natural := Natural (Data (12));
      begin
         if not Valid_Timestamp (Yr, Mo, Dy, Hr, Mi, Se) then
            return Fail (BE_Bad_Timestamp, 6);
         end if;
      end;

      declare
         Header_Len : constant Natural := 16;
         Count      : constant Natural := Get_U32_BE (Data, 13);
         Code_Len   : constant Natural := (Count + 7) / 8;
         Expected   : constant Natural := Header_Len + Code_Len;
      begin
         if Count = 0 then
            return Fail (BE_Empty_Program, 13);
         end if;

         if Len < Expected then
            return Fail (BE_Truncated, Header_Len + 1);
         end if;

         if Len > Expected then
            return Fail (BE_Extra_Bytes, Expected + 1);
         end if;

         declare
            Ops : Opcode_Array (1 .. Count);
            Bit_Pos : Natural := 0;
         begin
            for I in 1 .. Count loop
               declare
                  --  Code bits start after the 16-byte header.
                  Byte_Off : constant Natural :=
                    Header_Len + 1 + (Bit_Pos / 8);
                  Bit_In   : constant Natural := 7 - (Bit_Pos mod 8);
                  Mask     : constant Unsigned_32 :=
                    Shift_Left (Unsigned_32 (1), Bit_In);
                  Byte_Val : constant Unsigned_32 :=
                    Unsigned_32 (Data (Stream_Element_Offset (Byte_Off)));
               begin
                  if (Byte_Val and Mask) /= 0 then
                     Ops (I) := IR_Eml.One;
                  else
                     Ops (I) := IR_Eml.Eml;
                  end if;
                  Bit_Pos := Bit_Pos + 1;
               end;
            end loop;

            if Code_Len > 0 then
               declare
                  Last_Off  : constant Natural := Header_Len + Code_Len;
                  Last_Byte : constant Natural :=
                    Natural (Data (Stream_Element_Offset (Last_Off)));
                  Used_Bits : constant Natural := Count mod 8;
               begin
                  if Used_Bits /= 0 then
                     declare
                        Pad_Mask : Unsigned_32 := 0;
                     begin
                        for B in Used_Bits .. 7 loop
                           Pad_Mask :=
                             Pad_Mask
                             + Shift_Left (Unsigned_32 (1), 7 - B);
                        end loop;
                        if (Unsigned_32 (Last_Byte) and Pad_Mask) /= 0 then
                           return Fail (BE_Nonzero_Pad, Last_Off);
                        end if;
                     end;
                  end if;
               end;
            end if;

            return (Opcodes => new Opcode_Array'(Ops), others => <>);
         end;
      end;
   end Read_Bytes;

   function Read_File (Path : String) return Read_Result is
      File : Stream_IO.File_Type;
      Buffer : Stream_Element_Array (1 .. 1_000_000);
      Last   : Stream_Element_Offset;
   begin
      Stream_IO.Open (File, Stream_IO.In_File, Path);
      Stream_IO.Read (File, Buffer, Last);
      Stream_IO.Close (File);
      return Read_Bytes (Buffer (1 .. Last));
   exception
      when others =>
         if Stream_IO.Is_Open (File) then
            Stream_IO.Close (File);
         end if;
         raise;
   end Read_File;

end Beml_Reader;
