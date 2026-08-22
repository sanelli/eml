with Ada.Text_IO;
with IR_Eml;
with Teml_Parser;
with Teml_Tokenizer;

package body Teml_Parser_Tests is

   use type IR_Eml.Node_Kind;

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
         Tok : constant Teml_Tokenizer.Tokenize_Result :=
           Teml_Tokenizer.Tokenize ("eml(1,1)");
         Par : constant Teml_Parser.Parse_Result :=
           Teml_Parser.Parse (Tok.Tokens.all);
      begin
         Require (not Par.Had_Error, "teml-par: ok");
         Require
           (Par.Root.Kind = IR_Eml.Eml_Node, "teml-par: eml node");
      end;

      declare
         Tok : constant Teml_Tokenizer.Tokenize_Result :=
           Teml_Tokenizer.Tokenize ("eml(1)");
         Par : constant Teml_Parser.Parse_Result :=
           Teml_Parser.Parse (Tok.Tokens.all);
      begin
         Require (Par.Had_Error, "teml-par: eml1");
      end;
   end Run;

end Teml_Parser_Tests;
