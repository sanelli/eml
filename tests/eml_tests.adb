with Ada.Command_Line;
with Ada.Text_IO;

with CLI_Tests;
with Eml_Parser_Tests;
with Eml_Tokenizer_Tests;
with Beml_Parser_Tests;
with Beml_Reader_Tests;
with Teml_Parser_Tests;
with Teml_Tokenizer_Tests;
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
   Teml_Tokenizer_Tests.Run (Failed);
   Eml_Tokenizer_Tests.Run (Failed);
   Teml_Parser_Tests.Run (Failed);
   Eml_Parser_Tests.Run (Failed);
   Beml_Reader_Tests.Run (Failed);
   Beml_Parser_Tests.Run (Failed);

   --  Remaining stub
   Require (Interpreter.Name = "interpreter", "Interpreter.Name");

   if Failed then
      Ada.Text_IO.Put_Line ("eml_tests: FAILED");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   else
      Ada.Text_IO.Put_Line ("eml_tests: OK");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
   end if;
end Eml_Tests;
