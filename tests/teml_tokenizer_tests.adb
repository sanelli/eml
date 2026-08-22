with Ada.Text_IO;
with Teml_Tokenizer;

package body Teml_Tokenizer_Tests is

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
         R : constant Teml_Tokenizer.Tokenize_Result :=
           Teml_Tokenizer.Tokenize ("eml(1, 1)");
      begin
         Require (not R.Had_Errors, "teml-tok: ok");
         Require (R.Tokens'Length = 6, "teml-tok: count");
         Require
           (Teml_Tokenizer.Kind_Name (R.Tokens (1).Kind) = "EML",
            "teml-tok: eml");
      end;

      declare
         R : constant Teml_Tokenizer.Tokenize_Result :=
           Teml_Tokenizer.Tokenize ("1+");
      begin
         Require (R.Had_Errors, "teml-tok: bad");
      end;
   end Run;

end Teml_Tokenizer_Tests;
