with Ada.Calendar;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Dotnet_Backend;
with IR_Eml;

package body Dotnet_Backend_Tests is

   use Ada.Calendar;
   use Ada.Strings.Unbounded;
   use Dotnet_Backend;
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
           Format_CSharp_Program (Make_One, Test_Meta);
      begin
         Require (Has (Text, "public static int Main"), "csharp: main");
         Require (Has (Text, "Complex.Exp"), "csharp: exp");
         Require (Has (Text, "Complex.Log"), "csharp: log");
         Require
           (Has (Text, "new Complex(1.0, 0.0)"), "csharp: one literal");
         Require (Has (Text, "// Source: e.teml"), "csharp: source");
         Require (Has (Text, "public static Complex eml"), "csharp: eml");
         Require
           (Has (Text, "public static Complex Compute()"),
            "csharp: compute");
         Require (not Has (Text, "ONE"), "csharp: no flatten");
      end;

      declare
         Text : constant String :=
           Format_CSharp_Program (E_Tree, Test_Meta);
      begin
         Require
           (Has
              (Text,
               "eml(new Complex(1.0, 0.0), new Complex(1.0, 0.0))"),
            "csharp: e nested");
      end;

      declare
         Text : constant String :=
           Format_CSharp_Lib (E_Tree, Test_Meta);
      begin
         Require
           (Has (Text, "public static Complex Compute()"),
            "csharplib: compute");
         Require
           (Has
              (Text,
               "return eml(new Complex(1.0, 0.0), new Complex(1.0, 0.0));"),
            "csharplib: compute body");
         Require (not Has (Text, "Main"), "csharplib: no main");
         Require
           (Has (Text, "public static Complex eml"),
            "csharplib: eml");
      end;

      declare
         Text : constant String :=
           Format_CSharp_Lib (E_Tree, Test_Meta, "Eval");
      begin
         Require
           (Has (Text, "public static Complex Eval()"),
            "csharplib: renamed entry");
      end;

      declare
         Proj : constant String :=
           Format_Csproj ("out.cs", "net10.0", True);
      begin
         Require (Has (Proj, "<TargetFramework>net10.0</TargetFramework>"),
                  "csproj: tfm");
         Require (Has (Proj, "<OutputType>Exe</OutputType>"),
                  "csproj: exe");
         Require (Has (Proj, "out.cs"), "csproj: include");
      end;

      declare
         Proj : constant String :=
           Format_Csproj ("lib.cs", "netstandard2.1", False);
      begin
         Require
           (Has (Proj, "<TargetFramework>netstandard2.1</TargetFramework>"),
            "csproj: netstandard");
         Require (Has (Proj, "<OutputType>Library</OutputType>"),
                  "csproj: library");
      end;

      declare
         Path : constant String :=
           Companion_Csproj_Path ("/tmp/foo.cs");
      begin
         Require
           (Ada.Strings.Fixed.Index (Path, "foo.csproj") > 0,
            "csproj: companion path");
      end;
   end Run;

end Dotnet_Backend_Tests;
