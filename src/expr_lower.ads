--  Lower .teml syntax trees to IR EML via paper rewrite identities.
with Expr_Parser;
with IR_Eml;

package Expr_Lower is

   function Lower (Root : Expr_Parser.Node_Access) return IR_Eml.Node_Access;

end Expr_Lower;
