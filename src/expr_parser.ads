--  Parse .teml tokens into a syntax tree and emit dumps.
with Ada.Strings.Unbounded;
with Expr_Tokenizer;

package Expr_Parser is

   function Name return String;

   type Node_Kind is
     (Number_Node,
      Constant_Node,
      Variable_Node,
      UPlus_Node,
      UMinus_Node,
      Add_Node,
      Sub_Node,
      Mul_Node,
      Div_Node,
      IDiv_Node,
      Pow_Node,
      Call_Node);

   type Node;
   type Node_Access is access Node;

   type Node is record
      Kind   : Node_Kind;
      Lexeme : Ada.Strings.Unbounded.Unbounded_String;
      Line   : Positive := 1;
      Column : Positive := 1;
      Left   : Node_Access := null;
      Right  : Node_Access := null;
   end record;
   --  Binary: Left then Right. Unary/Call: Left only. Leaves: neither.

   type Output_Format is (Mermaid, Markdown, Dot, Svg);

   type Parse_Result is record
      Root       : Node_Access := null;
      Had_Error  : Boolean := False;
      Error_Line : Positive := 1;
      Error_Col  : Positive := 1;
      Message    : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   function Parse (Tokens : Expr_Tokenizer.Token_Array) return Parse_Result;
   --  Precedence-climbing parse. Stops at the first error.

   function Format_Mermaid (Root : Node_Access) return String;
   function Format_Markdown (Root : Node_Access) return String;
   function Format_Dot (Root : Node_Access) return String;
   function Format_Svg (Root : Node_Access) return String;

   function Format_Tree
     (Root : Node_Access; Fmt : Output_Format) return String;

   procedure Write_To_File
     (Root : Node_Access;
      Fmt  : Output_Format;
      Path : String);

   procedure Write_To_Stdout
     (Root : Node_Access; Fmt : Output_Format);

end Expr_Parser;
