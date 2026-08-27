with Ada.Calendar;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Fsharp_Backend;
with IR_Eml;

package body Fsharp_Backend_Tests is

   use Ada.Calendar;
   use Ada.Strings.Unbounded;
   use Fsharp_Backend;
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
           Format_FSharp_Program (Make_One, Test_Meta);
      begin
         Require (Has (Text, "[<EntryPoint>]"), "fsharp: entry");
         Require (Has (Text, "let eml"), "fsharp: eml");
         Require (Has (Text, "let Compute ()"), "fsharp: compute");
         Require (Has (Text, "Complex.Exp"), "fsharp: exp");
      end;

      declare
         Text : constant String :=
           Format_FSharp_Lib (E_Tree, Test_Meta);
      begin
         Require (Has (Text, "let Compute ()"), "fsharplib: compute");
         Require (not Has (Text, "EntryPoint"), "fsharplib: no entry");
      end;

      declare
         Proj : constant String :=
           Format_Fsproj ("out.fs", "net8.0", True);
      begin
         Require (Has (Proj, "<OutputType>Exe</OutputType>"), "fsproj: exe");
         Require (Has (Proj, "out.fs"), "fsproj: include");
      end;
   end Run;

end Fsharp_Backend_Tests;
