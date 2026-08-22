with Ada.Calendar;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with C_Backend;
with IR_Eml;

package body C_Backend_Tests is

   use Ada.Calendar;
   use Ada.Strings.Unbounded;
   use C_Backend;
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
           Format_C_Program (Make_One, Test_Meta);
      begin
         Require (Has (Text, "int main(void)"), "c: main");
         Require (Has (Text, "cexpl"), "c: cexpl");
         Require (Has (Text, "clogl"), "c: clogl");
         Require (Has (Text, "printf"), "c: printf");
         Require
           (Has (Text, "(1.0L + 0.0L * I)"), "c: one literal");
         Require
           (Has (Text, "/* Source: e.teml */"), "c: source");
         Require
           (Has (Text, "/* Compiler: eml */"), "c: compiler");
         Require
           (Has (Text, "static long double complex eml"),
            "c: static eml");
      end;

      declare
         Text : constant String :=
           Format_C_Program (E_Tree, Test_Meta);
      begin
         Require
           (Has
              (Text,
               "eml((1.0L + 0.0L * I), (1.0L + 0.0L * I))"),
            "c: e nested");
      end;

      declare
         Text : constant String :=
           Format_C_Lib (E_Tree, Test_Meta, "out.h");
      begin
         Require (Has (Text, "#include ""out.h"""), "clib: include");
         Require
           (Has (Text, "long double complex compute(void)"),
            "clib: compute");
         Require
           (Has (Text, "return eml((1.0L + 0.0L * I), "
            & "(1.0L + 0.0L * I));"),
            "clib: compute body");
         Require (not Has (Text, "int main"), "clib: no main");
         Require
           (Has (Text, "static long double complex eml"),
            "clib: eml static default");
      end;

      declare
         Text : constant String :=
           Format_C_Lib
             (E_Tree, Test_Meta, "out.h", "eval", True);
      begin
         Require
           (Has (Text, "long double complex eval(void)"),
            "clib: renamed entry");
         Require
           (Has (Text, "long double complex eml")
            and then not Has
              (Text, "static long double complex eml"),
            "clib: eml exported");
      end;

      declare
         Hdr : constant String := Format_C_Header ("OUT_H");
      begin
         Require (Has (Hdr, "#ifndef OUT_H"), "hdr: ifndef");
         Require (Has (Hdr, "#define OUT_H"), "hdr: define");
         Require
           (not Has (Hdr, "long double complex eml"),
            "hdr: no eml default");
         Require
           (Has (Hdr, "long double complex compute(void);"),
            "hdr: compute proto");
         Require (Has (Hdr, "#include <complex.h>"), "hdr: complex");
      end;

      declare
         Hdr : constant String :=
           Format_C_Header ("OUT_H", "eval", True);
      begin
         Require
           (Has
              (Hdr,
               "long double complex eml"
               & "(long double complex x, long double complex y);"),
            "hdr: eml proto");
         Require
           (Has (Hdr, "long double complex eval(void);"),
            "hdr: renamed proto");
      end;

      declare
         Path : constant String :=
           Companion_Header_Path ("/tmp/foo.c");
      begin
         Require
           (Path'Length >= 5
            and then Path (Path'Last - 4 .. Path'Last) = "foo.h",
            "hdr: companion basename");
      end;

      declare
         Guard : constant String := Header_Guard ("out-lib");
      begin
         Require (Guard = "OUT_LIB_H", "hdr: guard name");
      end;
   end Run;

end C_Backend_Tests;
