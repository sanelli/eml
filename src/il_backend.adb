with Ada.Strings.Unbounded;
with Ada.Text_IO;

package body Il_Backend is

   use Ada.Strings.Unbounded;
   use IR_Eml;

   Complex_Type : constant String :=
     "valuetype [System.Runtime.Numerics]"
     & "System.Numerics.Complex";

   procedure Append_Line
     (Buffer : in out Unbounded_String; Line : String)
   is
   begin
      if Length (Buffer) > 0 then
         Append (Buffer, ASCII.LF);
      end if;
      Append (Buffer, Line);
   end Append_Line;

   function Is_Netstandard (Tfm : String) return Boolean is
   begin
      return Tfm = "netstandard2.0" or else Tfm = "netstandard2.1";
   end Is_Netstandard;

   procedure Append_Assembly_Externs
     (Buffer : in out Unbounded_String; Tfm : String)
   is
   begin
      if Is_Netstandard (Tfm) then
         Append_Line (Buffer, ".assembly extern netstandard");
         Append_Line (Buffer, "{");
         Append_Line
           (Buffer,
            "  .publickeytoken = (CC 7B 13 FF CD 2D DD 51 )");
         Append_Line (Buffer, "  .ver 2:1:0:0");
         Append_Line (Buffer, "}");
      else
         Append_Line (Buffer, ".assembly extern System.Runtime");
         Append_Line (Buffer, "{");
         Append_Line
           (Buffer,
            "  .publickeytoken = (B0 3F 5F 7F 11 D5 0A 3A )");
         Append_Line (Buffer, "  .ver 8:0:0:0");
         Append_Line (Buffer, "}");
         Append_Line (Buffer, ".assembly extern System.Runtime.Numerics");
         Append_Line (Buffer, "{");
         Append_Line
           (Buffer,
            "  .publickeytoken = (B0 3F 5F 7F 11 D5 0A 3A )");
         Append_Line (Buffer, "  .ver 8:0:0:0");
         Append_Line (Buffer, "}");
         Append_Line (Buffer, ".assembly extern System.Console");
         Append_Line (Buffer, "{");
         Append_Line
           (Buffer,
            "  .publickeytoken = (B0 3F 5F 7F 11 D5 0A 3A )");
         Append_Line (Buffer, "  .ver 8:0:0:0");
         Append_Line (Buffer, "}");
      end if;
   end Append_Assembly_Externs;

   procedure Append_Complex_One (Buffer : in out Unbounded_String) is
   begin
      Append_Line (Buffer, "    ldc.r8 1.0");
      Append_Line (Buffer, "    ldc.r8 0.0");
      Append_Line
        (Buffer,
         "    newobj instance void "
         & "[System.Runtime.Numerics]System.Numerics.Complex::.ctor("
         & "float64, float64)");
   end Append_Complex_One;

   procedure Append_Expr_Il
     (Buffer : in out Unbounded_String; N : Node_Access);

   procedure Append_Expr_Il
     (Buffer : in out Unbounded_String; N : Node_Access)
   is
   begin
      if N = null then
         Append_Complex_One (Buffer);
         return;
      end if;
      case N.Kind is
         when One_Node =>
            Append_Complex_One (Buffer);
         when Eml_Node =>
            Append_Expr_Il (Buffer, N.Left);
            Append_Expr_Il (Buffer, N.Right);
            Append_Line
              (Buffer,
               "    call " & Complex_Type & " Eml::eml("
               & Complex_Type & ", " & Complex_Type & ")");
      end case;
   end Append_Expr_Il;

   procedure Append_Eml_Method (Buffer : in out Unbounded_String) is
   begin
      Append_Line
        (Buffer,
         "  .method public hidebysig static " & Complex_Type
         & " eml(" & Complex_Type & " x, " & Complex_Type & " y) "
         & "cil managed");
      Append_Line (Buffer, "  {");
      Append_Line (Buffer, "    .maxstack 8");
      Append_Line (Buffer, "    ldarg.0");
      Append_Line
        (Buffer,
         "    call " & Complex_Type
         & " [System.Runtime.Numerics]System.Numerics.Complex::Exp("
         & Complex_Type & ")");
      Append_Line (Buffer, "    ldarg.1");
      Append_Line
        (Buffer,
         "    call " & Complex_Type
         & " [System.Runtime.Numerics]System.Numerics.Complex::Log("
         & Complex_Type & ")");
      Append_Line
        (Buffer,
         "    call " & Complex_Type
         & " [System.Runtime.Numerics]System.Numerics.Complex::op_Subtraction("
         & Complex_Type & ", " & Complex_Type & ")");
      Append_Line (Buffer, "    ret");
      Append_Line (Buffer, "  }");
   end Append_Eml_Method;

   procedure Append_Compute_Method
     (Buffer        : in out Unbounded_String;
      Root          : Node_Access;
      Function_Name : String)
   is
   begin
      Append_Line
        (Buffer,
         "  .method public hidebysig static " & Complex_Type & " "
         & Function_Name & "() cil managed");
      Append_Line (Buffer, "  {");
      Append_Line (Buffer, "    .maxstack 8");
      Append_Expr_Il (Buffer, Root);
      Append_Line (Buffer, "    ret");
      Append_Line (Buffer, "  }");
   end Append_Compute_Method;

   procedure Append_Main_Method
     (Buffer : in out Unbounded_String; Function_Name : String)
   is
   begin
      Append_Line
        (Buffer,
         "  .method public hidebysig static int32 Main(string[] args) "
         & "cil managed");
      Append_Line (Buffer, "  {");
      Append_Line (Buffer, "    .entrypoint");
      Append_Line (Buffer, "    .maxstack 8");
      Append_Line
        (Buffer,
         "    call " & Complex_Type & " Eml::" & Function_Name & "()");
      Append_Line (Buffer, "    pop");
      Append_Line (Buffer, "    ldc.i4.0");
      Append_Line (Buffer, "    ret");
      Append_Line (Buffer, "  }");
   end Append_Main_Method;

   function Format_Il_Body
     (Root             : Node_Access;
      Meta             : Dump_Meta;
      Function_Name    : String;
      Target_Framework : String;
      With_Entrypoint  : Boolean) return String
   is
      Buffer : Unbounded_String := Null_Unbounded_String;
   begin
      Append_Line
        (Buffer,
         "// Source: " & To_String (Meta.Source_Path));
      Append_Line (Buffer, "// Compiler: eml");
      Append_Line
        (Buffer, "// Version: " & To_String (Meta.Version));
      Append_Line
        (Buffer, "// Date: " & UTC_Image (Meta.Compiled_At));
      Append_Line
        (Buffer, "// TargetFramework: " & Target_Framework);
      Append_Line (Buffer, "");
      Append_Assembly_Externs (Buffer, Target_Framework);
      Append_Line (Buffer, "");
      Append_Line (Buffer, ".class public auto ansi abstract sealed Eml");
      if Is_Netstandard (Target_Framework) then
         Append_Line
           (Buffer,
            "       extends [netstandard]System.Object");
      else
         Append_Line
           (Buffer,
            "       extends [System.Runtime]System.Object");
      end if;
      Append_Line (Buffer, "{");
      Append_Eml_Method (Buffer);
      Append_Line (Buffer, "");
      Append_Compute_Method (Buffer, Root, Function_Name);
      if With_Entrypoint then
         Append_Line (Buffer, "");
         Append_Main_Method (Buffer, Function_Name);
      end if;
      Append_Line (Buffer, "}");
      Append (Buffer, ASCII.LF);
      return To_String (Buffer);
   end Format_Il_Body;

   function Format_Il_Program
     (Root             : Node_Access;
      Meta             : Dump_Meta;
      Function_Name    : String := Default_Function_Name;
      Target_Framework : String := Default_Framework) return String
   is
   begin
      return Format_Il_Body
        (Root, Meta, Function_Name, Target_Framework, True);
   end Format_Il_Program;

   function Format_Il_Lib
     (Root             : Node_Access;
      Meta             : Dump_Meta;
      Function_Name    : String := Default_Function_Name;
      Target_Framework : String := Default_Framework) return String
   is
   begin
      return Format_Il_Body
        (Root, Meta, Function_Name, Target_Framework, False);
   end Format_Il_Lib;

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

   procedure Write_Il_Program_To_File
     (Root             : IR_Eml.Node_Access;
      Meta             : IR_Eml.Dump_Meta;
      Path             : String;
      Function_Name    : String := Default_Function_Name;
      Target_Framework : String := Default_Framework)
   is
   begin
      Write_Text_File
        (Path,
         Format_Il_Program (Root, Meta, Function_Name, Target_Framework));
   end Write_Il_Program_To_File;

   procedure Write_Il_Program_To_Stdout
     (Root             : IR_Eml.Node_Access;
      Meta             : IR_Eml.Dump_Meta;
      Function_Name    : String := Default_Function_Name;
      Target_Framework : String := Default_Framework)
   is
   begin
      Write_Text_Stdout
        (Format_Il_Program (Root, Meta, Function_Name, Target_Framework));
   end Write_Il_Program_To_Stdout;

   procedure Write_Il_Lib_To_File
     (Root             : IR_Eml.Node_Access;
      Meta             : IR_Eml.Dump_Meta;
      Path             : String;
      Function_Name    : String := Default_Function_Name;
      Target_Framework : String := Default_Framework)
   is
   begin
      Write_Text_File
        (Path,
         Format_Il_Lib (Root, Meta, Function_Name, Target_Framework));
   end Write_Il_Lib_To_File;

   procedure Write_Il_Lib_To_Stdout
     (Root             : IR_Eml.Node_Access;
      Meta             : IR_Eml.Dump_Meta;
      Function_Name    : String := Default_Function_Name;
      Target_Framework : String := Default_Framework)
   is
   begin
      Write_Text_Stdout
        (Format_Il_Lib (Root, Meta, Function_Name, Target_Framework));
   end Write_Il_Lib_To_Stdout;

end Il_Backend;
