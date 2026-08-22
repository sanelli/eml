with Ada.Calendar;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with IR_Eml;
with Js_Backend;

package body Js_Backend_Tests is

   use Ada.Calendar;
   use Ada.Strings.Unbounded;
   use IR_Eml;
   use Js_Backend;

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

   function Nested_Tree return Node_Access is
   begin
      return Make_Eml (E_Tree, Make_One);
   end Nested_Tree;

   procedure Run (Failed : in out Boolean) is

      procedure Require (Cond : Boolean; Message : String) is
      begin
         if not Cond then
            Failed := True;
            Ada.Text_IO.Put_Line ("FAIL: " & Message);
         end if;
      end Require;

      function Has (Haystack, Needle : String) return Boolean is
      begin
         return Ada.Strings.Fixed.Index (Haystack, Needle) > 0;
      end Has;

   begin
      declare
         Text : constant String := Format_Js (Make_One, Test_Meta);
      begin
         Require (Has (Text, "function main() {"), "js: main fn");
         Require
           (Has (Text, "  return math.complex(1, 0);"),
            "js: one return");
         Require
           (not Has (Text, "return eml("), "js: one no eml call");
         Require
           (Has
              (Text,
               "  return math.subtract(math.exp(x), math.log(y));"),
            "js: eml body");
         Require (Has (Text, "// Source: e.teml"), "js: source");
         Require (Has (Text, "// Compiler: eml"), "js: compiler");
         Require
           (Has (Text, "// Version: 0.1.0-dev"), "js: version");
         Require
           (Has
              (Text,
               "// Date: " & UTC_Image (Test_Meta.Compiled_At)),
            "js: date");
         Require (not Has (Text, "require("), "js: no require");
         Require (not Has (Text, "import "), "js: no import");
         Require
           (Ada.Strings.Fixed.Index (Text, "main();") = 0,
            "js: no top-level main();");
      end;

      declare
         Text : constant String := Format_Js (E_Tree, Test_Meta);
      begin
         Require
           (Has
              (Text,
               "  return eml(math.complex(1, 0), math.complex(1, 0));"),
            "js: e nested");
         Require (Has (Text, "function eml(x, y) {"), "js: eml fn");
      end;

      declare
         Text : constant String :=
           Format_Js (Nested_Tree, Test_Meta);
      begin
         Require
           (Has
              (Text,
               "  return eml(eml(math.complex(1, 0), "
               & "math.complex(1, 0)), math.complex(1, 0));"),
            "js: nested eml");
      end;

      declare
         Html : constant String := Format_Html ("out.js");
      begin
         Require (Has (Html, "<!DOCTYPE html>"), "html: doctype");
         Require
           (Has (Html, Mathjs_Script_Src), "html: mathjs cdn");
         Require
           (Has (Html, "<script src=""out.js""></script>"),
            "html: js src");
         Require (Has (Html, "id=""result"""), "html: result id");
         Require
           (Has (Html, "math.format(main())"), "html: main call");
      end;

      declare
         Path : constant String :=
           Companion_Html_Path ("/tmp/foo.js");
      begin
         Require
           (Path'Length >= 8
            and then Path (Path'Last - 7 .. Path'Last) = "foo.html",
            "html: companion basename");
         Require
           (Ada.Strings.Fixed.Index (Path, "tmp") > 0,
            "html: companion dir");
      end;
   end Run;

end Js_Backend_Tests;
