with Ada.Characters.Handling;
with Ada.Directories;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

package body C_Backend is

   use Ada.Strings.Unbounded;
   use IR_Eml;

   procedure Append_Line
     (Buffer : in out Unbounded_String; Line : String)
   is
   begin
      if Length (Buffer) > 0 then
         Append (Buffer, ASCII.LF);
      end if;
      Append (Buffer, Line);
   end Append_Line;

   procedure Append_Meta_Comments
     (Buffer : in out Unbounded_String; Meta : Dump_Meta)
   is
   begin
      Append_Line
        (Buffer, "/* Source: " & To_String (Meta.Source_Path) & " */");
      Append_Line (Buffer, "/* Compiler: eml */");
      Append_Line
        (Buffer, "/* Version: " & To_String (Meta.Version) & " */");
      Append_Line
        (Buffer, "/* Date: " & UTC_Image (Meta.Compiled_At) & " */");
   end Append_Meta_Comments;

   function Format_Expr (N : Node_Access) return String is
   begin
      if N = null then
         return "(1.0L + 0.0L * I)";
      end if;
      case N.Kind is
         when One_Node =>
            return "(1.0L + 0.0L * I)";
         when Eml_Node =>
            return
              "eml("
              & Format_Expr (N.Left)
              & ", "
              & Format_Expr (N.Right)
              & ")";
      end case;
   end Format_Expr;

   function Format_C_Program
     (Root : Node_Access; Meta : Dump_Meta) return String
   is
      Buffer : Unbounded_String := Null_Unbounded_String;
   begin
      Append_Meta_Comments (Buffer, Meta);
      Append_Line (Buffer, "");
      Append_Line (Buffer, "#include <complex.h>");
      Append_Line (Buffer, "#include <stdio.h>");
      Append_Line (Buffer, "");
      Append_Line
        (Buffer,
         "static long double complex eml"
         & "(long double complex x, long double complex y)");
      Append_Line (Buffer, "{");
      Append_Line (Buffer, "  return cexpl(x) - clogl(y);");
      Append_Line (Buffer, "}");
      Append_Line (Buffer, "");
      Append_Line (Buffer, "int main(void)");
      Append_Line (Buffer, "{");
      Append_Line
        (Buffer,
         "  long double complex z = " & Format_Expr (Root) & ";");
      Append_Line
        (Buffer,
         "  printf(""%Lf%+Lfi\n"", creall(z), cimagl(z));");
      Append_Line (Buffer, "  return 0;");
      Append_Line (Buffer, "}");
      Append (Buffer, ASCII.LF);
      return To_String (Buffer);
   end Format_C_Program;

   function Format_C_Lib
     (Root                : Node_Access;
      Meta                : Dump_Meta;
      Header_Include_Name : String) return String
   is
      Buffer : Unbounded_String := Null_Unbounded_String;
   begin
      Append_Meta_Comments (Buffer, Meta);
      Append_Line (Buffer, "");
      Append_Line
        (Buffer, "#include """ & Header_Include_Name & """");
      Append_Line (Buffer, "");
      Append_Line
        (Buffer,
         "long double complex eml"
         & "(long double complex x, long double complex y)");
      Append_Line (Buffer, "{");
      Append_Line (Buffer, "  return cexpl(x) - clogl(y);");
      Append_Line (Buffer, "}");
      Append_Line (Buffer, "");
      Append_Line (Buffer, "long double complex compute(void)");
      Append_Line (Buffer, "{");
      Append_Line (Buffer, "  return " & Format_Expr (Root) & ";");
      Append_Line (Buffer, "}");
      Append (Buffer, ASCII.LF);
      return To_String (Buffer);
   end Format_C_Lib;

   function Format_C_Header (Guard_Name : String) return String is
      Buffer : Unbounded_String := Null_Unbounded_String;
   begin
      Append_Line (Buffer, "#ifndef " & Guard_Name);
      Append_Line (Buffer, "#define " & Guard_Name);
      Append_Line (Buffer, "");
      Append_Line (Buffer, "#include <complex.h>");
      Append_Line (Buffer, "");
      Append_Line
        (Buffer,
         "long double complex eml"
         & "(long double complex x, long double complex y);");
      Append_Line
        (Buffer, "long double complex compute(void);");
      Append_Line (Buffer, "");
      Append_Line (Buffer, "#endif /* " & Guard_Name & " */");
      Append (Buffer, ASCII.LF);
      return To_String (Buffer);
   end Format_C_Header;

   function Companion_Header_Path (C_Path : String) return String is
      Dir  : constant String :=
        Ada.Directories.Containing_Directory (C_Path);
      Base : constant String :=
        Ada.Directories.Base_Name (C_Path);
   begin
      return Ada.Directories.Compose (Dir, Base & ".h");
   end Companion_Header_Path;

   function Header_Guard (Base_Name : String) return String is
      Result : String (1 .. Base_Name'Length + 2);
      Last   : Natural := 0;
   begin
      for C of Base_Name loop
         Last := Last + 1;
         if Ada.Characters.Handling.Is_Alphanumeric (C) then
            Result (Last) :=
              Ada.Characters.Handling.To_Upper (C);
         else
            Result (Last) := '_';
         end if;
      end loop;
      Result (Last + 1) := '_';
      Result (Last + 2) := 'H';
      return Result (1 .. Last + 2);
   end Header_Guard;

   procedure Write_Text_File (Path, Text : String) is
      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put (File, Text);
      Ada.Text_IO.Close (File);
   end Write_Text_File;

   procedure Write_Text_Stdout (Text : String) is
   begin
      Ada.Text_IO.Put (Ada.Text_IO.Standard_Output, Text);
      if Text'Length = 0 or else Text (Text'Last) /= ASCII.LF then
         Ada.Text_IO.New_Line (Ada.Text_IO.Standard_Output);
      end if;
   end Write_Text_Stdout;

   procedure Write_C_Program_To_File
     (Root : Node_Access; Meta : Dump_Meta; Path : String)
   is
   begin
      Write_Text_File (Path, Format_C_Program (Root, Meta));
   end Write_C_Program_To_File;

   procedure Write_C_Program_To_Stdout
     (Root : Node_Access; Meta : Dump_Meta)
   is
   begin
      Write_Text_Stdout (Format_C_Program (Root, Meta));
   end Write_C_Program_To_Stdout;

   procedure Write_C_Lib_To_File
     (Root : Node_Access; Meta : Dump_Meta; Path : String)
   is
      H_Path : constant String := Companion_Header_Path (Path);
      H_Name : constant String :=
        Ada.Directories.Simple_Name (H_Path);
      Guard  : constant String :=
        Header_Guard (Ada.Directories.Base_Name (Path));
   begin
      Write_Text_File
        (Path, Format_C_Lib (Root, Meta, H_Name));
      Write_Text_File (H_Path, Format_C_Header (Guard));
   end Write_C_Lib_To_File;

   procedure Write_C_Lib_To_Stdout
     (Root : Node_Access; Meta : Dump_Meta)
   is
   begin
      Write_Text_Stdout
        (Format_C_Lib (Root, Meta, "eml_generated.h"));
   end Write_C_Lib_To_Stdout;

end C_Backend;
