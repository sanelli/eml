with Ada.Directories;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

package body Vb_Backend is

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
        (Buffer, "' Source: " & To_String (Meta.Source_Path));
      Append_Line (Buffer, "' Compiler: eml");
      Append_Line
        (Buffer, "' Version: " & To_String (Meta.Version));
      Append_Line
        (Buffer, "' Date: " & UTC_Image (Meta.Compiled_At));
   end Append_Meta_Comments;

   function Format_Expr (N : Node_Access) return String is
   begin
      if N = null then
         return "New Complex(1.0, 0.0)";
      end if;
      case N.Kind is
         when One_Node =>
            return "New Complex(1.0, 0.0)";
         when Eml_Node =>
            return
              "eml("
              & Format_Expr (N.Left)
              & ", "
              & Format_Expr (N.Right)
              & ")";
      end case;
   end Format_Expr;

   procedure Append_Eml_Method (Buffer : in out Unbounded_String) is
   begin
      Append_Line
        (Buffer,
         "  Public Shared Function eml(x As Complex, y As Complex) "
         & "As Complex");
      Append_Line (Buffer, "    Return Complex.Subtract(Complex.Exp(x), "
         & "Complex.Log(y))");
      Append_Line (Buffer, "  End Function");
   end Append_Eml_Method;

   procedure Append_Compute_Method
     (Buffer        : in out Unbounded_String;
      Root          : Node_Access;
      Function_Name : String)
   is
   begin
      Append_Line
        (Buffer,
         "  Public Shared Function " & Function_Name & "() As Complex");
      Append_Line (Buffer, "    Return " & Format_Expr (Root));
      Append_Line (Buffer, "  End Function");
   end Append_Compute_Method;

   function Format_Vb_Program
     (Root          : Node_Access;
      Meta          : Dump_Meta;
      Function_Name : String := Default_Function_Name) return String
   is
      Buffer : Unbounded_String := Null_Unbounded_String;
   begin
      Append_Meta_Comments (Buffer, Meta);
      Append_Line (Buffer, "");
      Append_Line (Buffer, "Imports System");
      Append_Line (Buffer, "Imports System.Numerics");
      Append_Line (Buffer, "");
      Append_Line (Buffer, "Public Module EmlModule");
      Append_Eml_Method (Buffer);
      Append_Line (Buffer, "");
      Append_Compute_Method (Buffer, Root, Function_Name);
      Append_Line (Buffer, "");
      Append_Line (Buffer, "  Public Sub Main()");
      Append_Line
        (Buffer, "    Dim z As Complex = " & Function_Name & "()");
      Append_Line
        (Buffer,
         "    Console.WriteLine($""{z.Real}{z.Imaginary:+}i"")");
      Append_Line (Buffer, "  End Sub");
      Append_Line (Buffer, "End Module");
      Append (Buffer, ASCII.LF);
      return To_String (Buffer);
   end Format_Vb_Program;

   function Format_Vb_Lib
     (Root          : Node_Access;
      Meta          : Dump_Meta;
      Function_Name : String := Default_Function_Name) return String
   is
      Buffer : Unbounded_String := Null_Unbounded_String;
   begin
      Append_Meta_Comments (Buffer, Meta);
      Append_Line (Buffer, "");
      Append_Line (Buffer, "Imports System.Numerics");
      Append_Line (Buffer, "");
      Append_Line (Buffer, "Public Module EmlModule");
      Append_Eml_Method (Buffer);
      Append_Line (Buffer, "");
      Append_Compute_Method (Buffer, Root, Function_Name);
      Append_Line (Buffer, "End Module");
      Append (Buffer, ASCII.LF);
      return To_String (Buffer);
   end Format_Vb_Lib;

   function Format_Vbproj
     (Source_File_Name : String;
      Target_Framework : String := Default_Framework;
      Is_Executable    : Boolean := True) return String
   is
      Buffer : Unbounded_String := Null_Unbounded_String;
      Output : constant String :=
        (if Is_Executable then "Exe" else "Library");
   begin
      Append_Line (Buffer, "<Project Sdk=""Microsoft.NET.Sdk"">");
      Append_Line (Buffer, "  <PropertyGroup>");
      Append_Line
        (Buffer,
         "    <TargetFramework>" & Target_Framework & "</TargetFramework>");
      Append_Line
        (Buffer, "    <OutputType>" & Output & "</OutputType>");
      Append_Line
        (Buffer,
         "    <EnableDefaultCompileItems>false</EnableDefaultCompileItems>");
      Append_Line (Buffer, "  </PropertyGroup>");
      Append_Line (Buffer, "  <ItemGroup>");
      Append_Line
        (Buffer,
         "    <Compile Include=""" & Source_File_Name & """ />");
      Append_Line (Buffer, "  </ItemGroup>");
      Append_Line (Buffer, "</Project>");
      Append (Buffer, ASCII.LF);
      return To_String (Buffer);
   end Format_Vbproj;

   function Companion_Vbproj_Path (Vb_Path : String) return String is
      Dir  : constant String :=
        Ada.Directories.Containing_Directory (Vb_Path);
      Base : constant String := Ada.Directories.Base_Name (Vb_Path);
   begin
      return Ada.Directories.Compose (Dir, Base & ".vbproj");
   end Companion_Vbproj_Path;

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

   procedure Write_Vb_Program_To_File
     (Root                 : IR_Eml.Node_Access;
      Meta                 : IR_Eml.Dump_Meta;
      Path                 : String;
      Function_Name        : String := Default_Function_Name;
      Target_Framework     : String := Default_Framework;
      Write_Companion_Proj : Boolean := True)
   is
      Src_Name : constant String := Ada.Directories.Simple_Name (Path);
   begin
      Write_Text_File
        (Path, Format_Vb_Program (Root, Meta, Function_Name));
      if Write_Companion_Proj then
         Write_Text_File
           (Companion_Vbproj_Path (Path),
            Format_Vbproj (Src_Name, Target_Framework, True));
      end if;
   end Write_Vb_Program_To_File;

   procedure Write_Vb_Program_To_Stdout
     (Root          : IR_Eml.Node_Access;
      Meta          : IR_Eml.Dump_Meta;
      Function_Name : String := Default_Function_Name)
   is
   begin
      Write_Text_Stdout (Format_Vb_Program (Root, Meta, Function_Name));
   end Write_Vb_Program_To_Stdout;

   procedure Write_Vb_Lib_To_File
     (Root                 : IR_Eml.Node_Access;
      Meta                 : IR_Eml.Dump_Meta;
      Path                 : String;
      Function_Name        : String := Default_Function_Name;
      Target_Framework     : String := Default_Framework;
      Write_Companion_Proj : Boolean := True)
   is
      Src_Name : constant String := Ada.Directories.Simple_Name (Path);
   begin
      Write_Text_File
        (Path, Format_Vb_Lib (Root, Meta, Function_Name));
      if Write_Companion_Proj then
         Write_Text_File
           (Companion_Vbproj_Path (Path),
            Format_Vbproj (Src_Name, Target_Framework, False));
      end if;
   end Write_Vb_Lib_To_File;

   procedure Write_Vb_Lib_To_Stdout
     (Root          : IR_Eml.Node_Access;
      Meta          : IR_Eml.Dump_Meta;
      Function_Name : String := Default_Function_Name)
   is
   begin
      Write_Text_Stdout (Format_Vb_Lib (Root, Meta, Function_Name));
   end Write_Vb_Lib_To_Stdout;

end Vb_Backend;
