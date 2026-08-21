with Ada.Command_Line;
with Ada.Text_IO;

with CLI_Tests;
with Elm_Parser;
with Elm_Tokenizer;
with Expr_Parser_Tests;
with Expr_Tokenizer_Tests;
with Interpreter;
with IR_Elm;
with Regex_Automata_Tests;

procedure Elm_Tests is

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
   Expr_Tokenizer_Tests.Run (Failed);
   Expr_Parser_Tests.Run (Failed);
   CLI_Tests.Run (Failed);

   --  Remaining stubs still present
   Require (Elm_Tokenizer.Name = "elm_tokenizer", "Elm_Tokenizer.Name");
   Require (Elm_Parser.Name = "elm_parser", "Elm_Parser.Name");
   Require (IR_Elm.Name = "ir_elm", "IR_Elm.Name");
   Require (Interpreter.Name = "interpreter", "Interpreter.Name");

   if Failed then
      Ada.Text_IO.Put_Line ("elm_tests: FAILED");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   else
      Ada.Text_IO.Put_Line ("elm_tests: OK");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
   end if;
end Elm_Tests;
