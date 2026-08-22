with Ada.Text_IO;
with Beml_Parser;
with IR_Eml;

package body Beml_Parser_Tests is

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
         Ops : constant IR_Eml.Opcode_Array :=
           [IR_Eml.One, IR_Eml.One, IR_Eml.Eml];
         Par : constant Beml_Parser.Parse_Result :=
           Beml_Parser.Parse (Ops);
      begin
         Require (not Par.Had_Error, "beml-par: ok");
         Require
           (Par.Root.Kind = IR_Eml.Eml_Node, "beml-par: root");
      end;

      declare
         Ops : constant IR_Eml.Opcode_Array := [IR_Eml.Eml];
         Par : constant Beml_Parser.Parse_Result :=
           Beml_Parser.Parse (Ops);
      begin
         Require (Par.Had_Error, "beml-par: bad");
      end;
   end Run;

end Beml_Parser_Tests;
