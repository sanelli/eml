--  Compile IR EML to browser JavaScript (math.js) plus companion HTML.
with IR_Eml;

package Js_Backend is

   Mathjs_Script_Src : constant String :=
     "https://cdn.jsdelivr.net/npm/mathjs@14.5.2/lib/browser/math.js";

   function Format_Js
     (Root : IR_Eml.Node_Access; Meta : IR_Eml.Dump_Meta) return String;
   --  Header comments, eml(x,y), and main() returning nested eml calls.

   function Format_Html (Js_File_Name : String) return String;
   --  Companion HTML; Js_File_Name is the simple name for <script src>.

   function Companion_Html_Path (Js_Path : String) return String;
   --  Same directory and basename as Js_Path, with .html extension.

   procedure Write_Js_To_File
     (Root : IR_Eml.Node_Access; Meta : IR_Eml.Dump_Meta; Path : String);

   procedure Write_Js_To_Stdout
     (Root : IR_Eml.Node_Access; Meta : IR_Eml.Dump_Meta);

   procedure Write_Html_To_File (Js_Path : String);
   --  Write companion HTML beside Js_Path using Simple_Name for script src.

end Js_Backend;
