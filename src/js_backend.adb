with Ada.Directories;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

package body Js_Backend is

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

   function Format_Expr (N : Node_Access) return String is
   begin
      if N = null then
         return "math.complex(1, 0)";
      end if;
      case N.Kind is
         when One_Node =>
            return "math.complex(1, 0)";
         when Eml_Node =>
            return
              "eml("
              & Format_Expr (N.Left)
              & ", "
              & Format_Expr (N.Right)
              & ")";
      end case;
   end Format_Expr;

   function Format_Js
     (Root          : Node_Access;
      Meta          : Dump_Meta;
      Function_Name : String := Default_Function_Name) return String
   is
      Buffer : Unbounded_String := Null_Unbounded_String;
   begin
      Append_Line
        (Buffer, "// Source: " & To_String (Meta.Source_Path));
      Append_Line (Buffer, "// Compiler: eml");
      Append_Line
        (Buffer, "// Version: " & To_String (Meta.Version));
      Append_Line
        (Buffer, "// Date: " & UTC_Image (Meta.Compiled_At));
      Append_Line (Buffer, "");
      Append_Line (Buffer, "function eml(x, y) {");
      Append_Line
        (Buffer,
         "  return math.subtract(math.exp(x), math.log(y));");
      Append_Line (Buffer, "}");
      Append_Line (Buffer, "");
      Append_Line (Buffer, "function " & Function_Name & "() {");
      Append_Line (Buffer, "  return " & Format_Expr (Root) & ";");
      Append_Line (Buffer, "}");
      Append (Buffer, ASCII.LF);
      return To_String (Buffer);
   end Format_Js;

   function Format_Html
     (Js_File_Name  : String;
      Function_Name : String := Default_Function_Name) return String
   is
      Buffer : Unbounded_String := Null_Unbounded_String;
   begin
      Append_Line (Buffer, "<!DOCTYPE html>");
      Append_Line (Buffer, "<html lang=""en"">");
      Append_Line (Buffer, "<head>");
      Append_Line (Buffer, "  <meta charset=""utf-8"">");
      Append_Line (Buffer, "  <title>EML</title>");
      Append_Line
        (Buffer,
         "  <script src=""" & Mathjs_Script_Src & """></script>");
      Append_Line
        (Buffer,
         "  <script src=""" & Js_File_Name & """></script>");
      Append_Line (Buffer, "</head>");
      Append_Line (Buffer, "<body>");
      Append_Line (Buffer, "  <pre id=""result""></pre>");
      Append_Line (Buffer, "  <script>");
      Append_Line
        (Buffer,
         "    document.getElementById(""result"").textContent "
         & "= math.format("
         & Function_Name
         & "());");
      Append_Line (Buffer, "  </script>");
      Append_Line (Buffer, "</body>");
      Append_Line (Buffer, "</html>");
      Append (Buffer, ASCII.LF);
      return To_String (Buffer);
   end Format_Html;

   function Companion_Html_Path (Js_Path : String) return String is
      Dir  : constant String :=
        Ada.Directories.Containing_Directory (Js_Path);
      Base : constant String :=
        Ada.Directories.Base_Name (Js_Path);
   begin
      return Ada.Directories.Compose (Dir, Base & ".html");
   end Companion_Html_Path;

   procedure Write_Js_To_File
     (Root          : Node_Access;
      Meta          : Dump_Meta;
      Path          : String;
      Function_Name : String := Default_Function_Name)
   is
      File : Ada.Text_IO.File_Type;
      Text : constant String :=
        Format_Js (Root, Meta, Function_Name);
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put (File, Text);
      Ada.Text_IO.Close (File);
   end Write_Js_To_File;

   procedure Write_Js_To_Stdout
     (Root          : Node_Access;
      Meta          : Dump_Meta;
      Function_Name : String := Default_Function_Name)
   is
      Text : constant String :=
        Format_Js (Root, Meta, Function_Name);
   begin
      Ada.Text_IO.Put (Ada.Text_IO.Standard_Output, Text);
      if Text'Length = 0 or else Text (Text'Last) /= ASCII.LF then
         Ada.Text_IO.New_Line (Ada.Text_IO.Standard_Output);
      end if;
   end Write_Js_To_Stdout;

   procedure Write_Html_To_File
     (Js_Path       : String;
      Function_Name : String := Default_Function_Name)
   is
      File : Ada.Text_IO.File_Type;
      Text : constant String :=
        Format_Html
          (Ada.Directories.Simple_Name (Js_Path), Function_Name);
      Path : constant String := Companion_Html_Path (Js_Path);
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put (File, Text);
      Ada.Text_IO.Close (File);
   end Write_Html_To_File;

end Js_Backend;
