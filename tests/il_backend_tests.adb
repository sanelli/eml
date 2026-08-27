with Ada.Calendar;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Il_Backend;
with IR_Eml;

package body Il_Backend_Tests is

   use Ada.Calendar;
   use Ada.Strings.Unbounded;
   use Il_Backend;
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
         Text : constant String :=
           Format_Il_Program (E_Tree, Test_Meta);
      begin
         Require (Has (Text, ".entrypoint"), "dotil: entrypoint");
         Require (Has (Text, " Eml::eml"), "dotil: eml");
         Require (Has (Text, " Eml::Compute"), "dotil: compute");
         Require (Has (Text, "// TargetFramework: net8.0"), "dotil: tfm");
      end;

      declare
         Text : constant String :=
           Format_Il_Lib (E_Tree, Test_Meta, "Eval", "netstandard2.1");
      begin
         Require (Has (Text, " Eval()"), "dotillib: renamed");
         Require (not Has (Text, ".entrypoint"), "dotillib: no entry");
         Require (Has (Text, "netstandard"), "dotillib: netstandard");
      end;
   end Run;

end Il_Backend_Tests;
