with Ada.Text_IO;
with Eml_Parser;
with Eml_Tokenizer;
with IR_Eml;

package body Eml_Parser_Tests is

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
         Tok : constant Eml_Tokenizer.Tokenize_Result :=
           Eml_Tokenizer.Tokenize
             ("ONE" & ASCII.LF & "ONE" & ASCII.LF & "EML");
         Par : constant Eml_Parser.Parse_Result :=
           Eml_Parser.Parse (Tok.Tokens.all);
      begin
         Require (not Par.Had_Error, "eml-par: ok");
         Require
           (Par.Root.Kind = IR_Eml.Eml_Node, "eml-par: root");
      end;

      declare
         Tok : constant Eml_Tokenizer.Tokenize_Result :=
           Eml_Tokenizer.Tokenize ("EML");
         Par : constant Eml_Parser.Parse_Result :=
           Eml_Parser.Parse (Tok.Tokens.all);
      begin
         Require (Par.Had_Error, "eml-par: underflow");
      end;
   end Run;

end Eml_Parser_Tests;
