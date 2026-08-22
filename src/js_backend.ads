--  Compile IR EML to browser JavaScript (math.js) plus companion HTML.
with IR_Eml;

package Js_Backend is

   Mathjs_Script_Src : constant String :=
     "https://cdn.jsdelivr.net/npm/mathjs@14.5.2/lib/browser/math.js";

   Default_Function_Name : constant String := "main";

   function Format_Js
     (Root          : IR_Eml.Node_Access;
      Meta          : IR_Eml.Dump_Meta;
      Function_Name : String := Default_Function_Name) return String;
   --  Header comments, eml(x,y), and entry function returning nested eml.

   function Format_Html
     (Js_File_Name  : String;
      Function_Name : String := Default_Function_Name) return String;
   --  Companion HTML; calls Function_Name via math.format.

   function Companion_Html_Path (Js_Path : String) return String;
   --  Same directory and basename as Js_Path, with .html extension.

   procedure Write_Js_To_File
     (Root          : IR_Eml.Node_Access;
      Meta          : IR_Eml.Dump_Meta;
      Path          : String;
      Function_Name : String := Default_Function_Name);

   procedure Write_Js_To_Stdout
     (Root          : IR_Eml.Node_Access;
      Meta          : IR_Eml.Dump_Meta;
      Function_Name : String := Default_Function_Name);

   procedure Write_Html_To_File
     (Js_Path       : String;
      Function_Name : String := Default_Function_Name);
   --  Write companion HTML beside Js_Path using Simple_Name for script src.

end Js_Backend;
