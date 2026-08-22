with Ada.Command_Line;
with Ada.Text_IO;

with CLI_Tests;
with Eml_Parser;
with Eml_Tokenizer;
with Expr_Preprocessor_Tests;
with Expr_Lower_Tests;
with Expr_Parser_Tests;
with Expr_Tokenizer_Tests;
with Interpreter;
with IR_Eml_Tests;
with Regex_Automata_Tests;

procedure Eml_Tests is

   Failed : Boolean := False;

   procedure Require (Cond : Boolean; Message : String) is
   begin
      if not Cond then
         Failed := True;
         Ada.Text_IO.Put_Line ("FAIL: " & Message);
      end if;
   end Require;

begin
   Regex_Automata_Tests.Run (Failed);
   Expr_Preprocessor_Tests.Run (Failed);
   Expr_Tokenizer_Tests.Run (Failed);
   Expr_Parser_Tests.Run (Failed);
   IR_Eml_Tests.Run (Failed);
   Expr_Lower_Tests.Run (Failed);
   CLI_Tests.Run (Failed);

   --  Remaining stubs still present
   Require (Eml_Tokenizer.Name = "eml_tokenizer", "Eml_Tokenizer.Name");
   Require (Eml_Parser.Name = "eml_parser", "Eml_Parser.Name");
   Require (Interpreter.Name = "interpreter", "Interpreter.Name");

   if Failed then
      Ada.Text_IO.Put_Line ("eml_tests: FAILED");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   else
      Ada.Text_IO.Put_Line ("eml_tests: OK");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
   end if;
end Eml_Tests;
