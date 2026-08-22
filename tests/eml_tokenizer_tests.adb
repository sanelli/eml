with Ada.Text_IO;
with Eml_Tokenizer;

package body Eml_Tokenizer_Tests is

   procedure Run (Failed : in out Boolean) is
      procedure Require (Cond : Boolean; Msg : String) is
      begin
         if not Cond then
            Failed := True;
            Ada.Text_IO.Put_Line ("FAIL: " & Msg);
         end if;
      end Require;
   begin
      declare
         R : constant Eml_Tokenizer.Tokenize_Result :=
           Eml_Tokenizer.Tokenize
             ("-- header" & ASCII.LF & "ONE" & ASCII.LF & "EML  -- e");
      begin
         Require (not R.Had_Errors, "eml-tok: ok");
         Require (R.Tokens'Length = 2, "eml-tok: count");
         Require
           (Eml_Tokenizer.Kind_Name (R.Tokens (2).Kind) = "EML",
            "eml-tok: eml");
      end;

      declare
         R : constant Eml_Tokenizer.Tokenize_Result :=
           Eml_Tokenizer.Tokenize ("BAD");
      begin
         Require (R.Had_Errors, "eml-tok: bad");
      end;
   end Run;

end Eml_Tokenizer_Tests;
