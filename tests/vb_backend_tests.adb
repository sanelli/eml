with Ada.Calendar;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with IR_Eml;
with Vb_Backend;

package body Vb_Backend_Tests is

   use Ada.Calendar;
   use Ada.Strings.Unbounded;
   use IR_Eml;
   use Vb_Backend;

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
           Format_Vb_Program (Make_One, Test_Meta);
      begin
         Require (Has (Text, "Public Module EmlModule"), "vb: module");
         Require (Has (Text, "Function eml"), "vb: eml");
         Require (Has (Text, "Public Sub Main()"), "vb: main");
         Require (Has (Text, "Function Compute()"), "vb: compute");
      end;

      declare
         Text : constant String :=
           Format_Vb_Lib (E_Tree, Test_Meta);
      begin
         Require (Has (Text, "Function Compute()"), "vblib: compute");
         Require (not Has (Text, "Sub Main"), "vblib: no main");
      end;

      declare
         Proj : constant String :=
           Format_Vbproj ("out.vb", "netstandard2.0", False);
      begin
         Require
           (Has (Proj, "<TargetFramework>netstandard2.0</TargetFramework>"),
            "vbproj: tfm");
      end;
   end Run;

end Vb_Backend_Tests;
