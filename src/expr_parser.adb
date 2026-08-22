with Ada.Text_IO;

package body Expr_Parser is

   use Ada.Strings.Unbounded;
   use type Expr_Tokenizer.Token_Kind;

   function Name return String is
   begin
      return "expr_parser";
   end Name;

   function Trim_Positive (N : Positive) return String is
      S : constant String := Positive'Image (N);
   begin
      if S (S'First) = ' ' then
         return S (S'First + 1 .. S'Last);
      end if;
      return S;
   end Trim_Positive;

   function Node_Label (N : Node_Access) return String is
   begin
      case N.Kind is
         when Number_Node | Constant_Node | Variable_Node | Call_Node =>
            return To_String (N.Lexeme);
         when UPlus_Node =>
            return "u+";
         when UMinus_Node =>
            return "u-";
         when Add_Node =>
            return "+";
         when Sub_Node =>
            return "-";
         when Mul_Node =>
            return "*";
         when Div_Node =>
            return "/";
         when Pow_Node =>
            return "^";
      end case;
   end Node_Label;

   ---------------------------------------------------------------------------
   --  Parser
   ---------------------------------------------------------------------------

   function Parse (Tokens : Expr_Tokenizer.Token_Array) return Parse_Result is
      Pos    : Natural := Tokens'First;
      Result : Parse_Result;

      procedure Fail (Line, Col : Positive; Msg : String) is
      begin
         Result.Had_Error := True;
         Result.Error_Line := Line;
         Result.Error_Col := Col;
         Result.Message := To_Unbounded_String (Msg);
         Result.Root := null;
      end Fail;

      function At_End return Boolean is
        (Pos > Tokens'Last);

      function Peek return Expr_Tokenizer.Token is
        (Tokens (Pos));

      procedure Advance is
      begin
         Pos := Pos + 1;
      end Advance;

      function Make_Leaf
        (Kind : Node_Kind; T : Expr_Tokenizer.Token) return Node_Access
      is
         N : constant Node_Access := new Node;
      begin
         N.Kind := Kind;
         N.Lexeme := T.Lexeme;
         N.Line := T.Line;
         N.Column := T.Column;
         return N;
      end Make_Leaf;

      function Make_Unary
        (Kind : Node_Kind;
         T    : Expr_Tokenizer.Token;
         Child : Node_Access) return Node_Access
      is
         N : constant Node_Access := new Node;
      begin
         N.Kind := Kind;
         N.Line := T.Line;
         N.Column := T.Column;
         N.Left := Child;
         return N;
      end Make_Unary;

      function Make_Binary
        (Kind  : Node_Kind;
         T     : Expr_Tokenizer.Token;
         Left  : Node_Access;
         Right : Node_Access) return Node_Access
      is
         N : constant Node_Access := new Node;
      begin
         N.Kind := Kind;
         N.Line := T.Line;
         N.Column := T.Column;
         N.Left := Left;
         N.Right := Right;
         return N;
      end Make_Binary;

      function Make_Call
        (T     : Expr_Tokenizer.Token;
         Child : Node_Access) return Node_Access
      is
         N : constant Node_Access := new Node;
      begin
         N.Kind := Call_Node;
         N.Lexeme := T.Lexeme;
         N.Line := T.Line;
         N.Column := T.Column;
         N.Left := Child;
         return N;
      end Make_Call;

      --  Precedence levels (higher binds tighter):
      --  1 = add/sub, 2 = mul/div, 3 = power
      --  Unary prefix uses Min_Bp = 3 so power binds tighter than unary.
      function Lbp (Kind : Expr_Tokenizer.Token_Kind) return Natural is
      begin
         case Kind is
            when Expr_Tokenizer.Plus | Expr_Tokenizer.Minus =>
               return 1;
            when Expr_Tokenizer.Star | Expr_Tokenizer.Slash =>
               return 2;
            when Expr_Tokenizer.Caret =>
               return 3;
            when others =>
               return 0;
         end case;
      end Lbp;

      function Is_Right_Assoc
        (Kind : Expr_Tokenizer.Token_Kind) return Boolean
      is
        (Kind = Expr_Tokenizer.Caret);

      function Binary_Kind
        (Kind : Expr_Tokenizer.Token_Kind) return Node_Kind
      is
      begin
         case Kind is
            when Expr_Tokenizer.Plus =>
               return Add_Node;
            when Expr_Tokenizer.Minus =>
               return Sub_Node;
            when Expr_Tokenizer.Star =>
               return Mul_Node;
            when Expr_Tokenizer.Slash =>
               return Div_Node;
            when Expr_Tokenizer.Caret =>
               return Pow_Node;
            when others =>
               raise Program_Error;
         end case;
      end Binary_Kind;

      function Parse_Expr (Min_Bp : Natural) return Node_Access;

      function Parse_Primary return Node_Access is
      begin
         if At_End then
            Fail (1, 1, "unexpected end of input");
            return null;
         end if;

         declare
            T : constant Expr_Tokenizer.Token := Peek;
         begin
            case T.Kind is
               when Expr_Tokenizer.Number =>
                  Advance;
                  return Make_Leaf (Number_Node, T);

               when Expr_Tokenizer.Constant_Name =>
                  Advance;
                  return Make_Leaf (Constant_Node, T);

               when Expr_Tokenizer.Variable =>
                  Advance;
                  return Make_Leaf (Variable_Node, T);

               when Expr_Tokenizer.Plus =>
                  Advance;
                  declare
                     Child : constant Node_Access := Parse_Expr (3);
                  begin
                     if Result.Had_Error then
                        return null;
                     end if;
                     return Make_Unary (UPlus_Node, T, Child);
                  end;

               when Expr_Tokenizer.Minus =>
                  Advance;
                  declare
                     Child : constant Node_Access := Parse_Expr (3);
                  begin
                     if Result.Had_Error then
                        return null;
                     end if;
                     return Make_Unary (UMinus_Node, T, Child);
                  end;

               when Expr_Tokenizer.LParen =>
                  Advance;
                  declare
                     Inner : constant Node_Access := Parse_Expr (0);
                  begin
                     if Result.Had_Error then
                        return null;
                     end if;
                     if At_End then
                        Fail
                          (T.Line, T.Column, "expected ')'");
                        return null;
                     end if;
                     if Peek.Kind /= Expr_Tokenizer.RParen then
                        Fail
                          (Peek.Line,
                           Peek.Column,
                           "expected ')'");
                        return null;
                     end if;
                     Advance;
                     return Inner;
                  end;

               when Expr_Tokenizer.Function_Name =>
                  Advance;
                  if At_End then
                     Fail
                       (T.Line,
                        T.Column,
                        "expected '(' after function '"
                        & To_String (T.Lexeme)
                        & "'");
                     return null;
                  end if;
                  if Peek.Kind /= Expr_Tokenizer.LParen then
                     Fail
                       (Peek.Line,
                        Peek.Column,
                        "expected '(' after function '"
                        & To_String (T.Lexeme)
                        & "'");
                     return null;
                  end if;
                  Advance;  --  (
                  if not At_End and then Peek.Kind = Expr_Tokenizer.RParen then
                     Fail
                       (Peek.Line,
                        Peek.Column,
                        "unexpected token ')'");
                     return null;
                  end if;
                  declare
                     Arg : constant Node_Access := Parse_Expr (0);
                  begin
                     if Result.Had_Error then
                        return null;
                     end if;
                     if At_End then
                        Fail
                          (T.Line, T.Column, "expected ')'");
                        return null;
                     end if;
                     if Peek.Kind /= Expr_Tokenizer.RParen then
                        Fail
                          (Peek.Line,
                           Peek.Column,
                           "expected ')'");
                        return null;
                     end if;
                     Advance;
                     return Make_Call (T, Arg);
                  end;

               when others =>
                  Fail
                    (T.Line,
                     T.Column,
                     "unexpected token '"
                     & To_String (T.Lexeme)
                     & "'");
                  return null;
            end case;
         end;
      end Parse_Primary;

      function Parse_Expr (Min_Bp : Natural) return Node_Access is
         Left : Node_Access := Parse_Primary;
      begin
         if Result.Had_Error then
            return null;
         end if;

         loop
            exit when At_End;
            declare
               Op_Bp : constant Natural := Lbp (Peek.Kind);
            begin
               exit when Op_Bp < Min_Bp or else Op_Bp = 0;

               declare
                  Op_Tok : constant Expr_Tokenizer.Token := Peek;
                  Next_Bp : Natural;
                  Right   : Node_Access;
               begin
                  Advance;
                  if Is_Right_Assoc (Op_Tok.Kind) then
                     Next_Bp := Op_Bp;
                  else
                     Next_Bp := Op_Bp + 1;
                  end if;
                  Right := Parse_Expr (Next_Bp);
                  if Result.Had_Error then
                     return null;
                  end if;
                  Left := Make_Binary
                    (Binary_Kind (Op_Tok.Kind), Op_Tok, Left, Right);
               end;
            end;
         end loop;

         return Left;
      end Parse_Expr;

   begin
      if Tokens'Length = 0 then
         Fail (1, 1, "unexpected end of input");
         return Result;
      end if;

      Result.Root := Parse_Expr (0);
      if Result.Had_Error then
         return Result;
      end if;

      if not At_End then
         Fail
           (Peek.Line,
            Peek.Column,
            "unexpected token after expression");
         Result.Root := null;
         return Result;
      end if;

      return Result;
   end Parse;

   ---------------------------------------------------------------------------
   --  Tree walk helpers for emitters
   ---------------------------------------------------------------------------

   type Id_Map is array (Positive range <>) of Node_Access;

   procedure Count_Nodes (N : Node_Access; Count : in out Natural) is
   begin
      if N = null then
         return;
      end if;
      Count := Count + 1;
      Count_Nodes (N.Left, Count);
      Count_Nodes (N.Right, Count);
   end Count_Nodes;

   procedure Assign_Ids
     (N : Node_Access; Map : in out Id_Map; Next : in out Positive)
   is
   begin
      if N = null then
         return;
      end if;
      Map (Next) := N;
      Next := Next + 1;
      Assign_Ids (N.Left, Map, Next);
      Assign_Ids (N.Right, Map, Next);
   end Assign_Ids;

   function Find_Id (Map : Id_Map; N : Node_Access) return Positive is
   begin
      for I in Map'Range loop
         if Map (I) = N then
            return I;
         end if;
      end loop;
      raise Program_Error;
   end Find_Id;

   function Escape_Xml (S : String) return String is
      Buffer : Unbounded_String;
   begin
      for C of S loop
         case C is
            when '&' =>
               Append (Buffer, "&amp;");
            when '<' =>
               Append (Buffer, "&lt;");
            when '>' =>
               Append (Buffer, "&gt;");
            when '"' =>
               Append (Buffer, "&quot;");
            when ''' =>
               Append (Buffer, "&apos;");
            when others =>
               Append (Buffer, C);
         end case;
      end loop;
      return To_String (Buffer);
   end Escape_Xml;

   ---------------------------------------------------------------------------
   --  Mermaid / Markdown / DOT
   ---------------------------------------------------------------------------

   function Format_Mermaid (Root : Node_Access) return String is
      Total : Natural := 0;
      Buffer : Unbounded_String;
   begin
      Count_Nodes (Root, Total);
      declare
         Map  : Id_Map (1 .. Total);
         Next : Positive := 1;
      begin
         Assign_Ids (Root, Map, Next);
         Append (Buffer, "flowchart TD");
         Append (Buffer, ASCII.LF);
         for I in Map'Range loop
            Append
              (Buffer,
               "  n"
               & Trim_Positive (I)
               & "["""
               & Node_Label (Map (I))
               & """]");
            Append (Buffer, ASCII.LF);
         end loop;
         for I in Map'Range loop
            declare
               N : constant Node_Access := Map (I);
            begin
               if N.Left /= null then
                  Append
                    (Buffer,
                     "  n"
                     & Trim_Positive (I)
                     & " --> n"
                     & Trim_Positive (Find_Id (Map, N.Left)));
                  Append (Buffer, ASCII.LF);
               end if;
               if N.Right /= null then
                  Append
                    (Buffer,
                     "  n"
                     & Trim_Positive (I)
                     & " --> n"
                     & Trim_Positive (Find_Id (Map, N.Right)));
                  Append (Buffer, ASCII.LF);
               end if;
            end;
         end loop;
         --  Drop trailing newline for a clean file; keep structure with LF
         --  between lines. Plan gold ends without requiring trailing NL.
         declare
            S : constant String := To_String (Buffer);
         begin
            if S'Length > 0 and then S (S'Last) = ASCII.LF then
               return S (S'First .. S'Last - 1);
            end if;
            return S;
         end;
      end;
   end Format_Mermaid;

   function Format_Markdown (Root : Node_Access) return String is
      M : constant String := Format_Mermaid (Root);
   begin
      return "# Syntax tree"
        & ASCII.LF
        & ASCII.LF
        & "```mermaid"
        & ASCII.LF
        & M
        & ASCII.LF
        & "```";
   end Format_Markdown;

   function Format_Dot (Root : Node_Access) return String is
      Total  : Natural := 0;
      Buffer : Unbounded_String;
   begin
      Count_Nodes (Root, Total);
      declare
         Map  : Id_Map (1 .. Total);
         Next : Positive := 1;
      begin
         Assign_Ids (Root, Map, Next);
         Append (Buffer, "digraph syntaxtree {");
         Append (Buffer, ASCII.LF);
         for I in Map'Range loop
            Append
              (Buffer,
               "  n"
               & Trim_Positive (I)
               & " [label="""
               & Node_Label (Map (I))
               & """];");
            Append (Buffer, ASCII.LF);
         end loop;
         for I in Map'Range loop
            declare
               N : constant Node_Access := Map (I);
            begin
               if N.Left /= null then
                  Append
                    (Buffer,
                     "  n"
                     & Trim_Positive (I)
                     & " -> n"
                     & Trim_Positive (Find_Id (Map, N.Left))
                     & ";");
                  Append (Buffer, ASCII.LF);
               end if;
               if N.Right /= null then
                  Append
                    (Buffer,
                     "  n"
                     & Trim_Positive (I)
                     & " -> n"
                     & Trim_Positive (Find_Id (Map, N.Right))
                     & ";");
                  Append (Buffer, ASCII.LF);
               end if;
            end;
         end loop;
         Append (Buffer, "}");
         return To_String (Buffer);
      end;
   end Format_Dot;

   ---------------------------------------------------------------------------
   --  SVG (deterministic top-down layout)
   ---------------------------------------------------------------------------

   Box_W      : constant := 48;
   Box_H      : constant := 28;
   H_Gap      : constant := 16;
   V_Gap      : constant := 40;
   Margin     : constant := 20;

   type Layout_Info is record
      X      : Integer := 0;
      Y      : Integer := 0;
      Subtree_W : Integer := 0;
   end record;

   type Layout_Array is array (Positive range <>) of Layout_Info;

   function Subtree_Width (N : Node_Access) return Integer is
   begin
      if N = null then
         return 0;
      end if;
      if N.Left = null and then N.Right = null then
         return Box_W;
      end if;
      if N.Right = null then
         return Integer'Max (Box_W, Subtree_Width (N.Left));
      end if;
      return Subtree_Width (N.Left) + H_Gap + Subtree_Width (N.Right);
   end Subtree_Width;

   procedure Place
     (N       : Node_Access;
      Map     : Id_Map;
      Layout  : in out Layout_Array;
      Left_X  : Integer;
      Depth   : Natural)
   is
      Id : constant Positive := Find_Id (Map, N);
      W  : constant Integer := Subtree_Width (N);
   begin
      Layout (Id).Subtree_W := W;
      Layout (Id).Y := Margin + Depth * (Box_H + V_Gap);
      Layout (Id).X := Left_X + (W - Box_W) / 2;

      if N.Left /= null and then N.Right = null then
         Place (N.Left, Map, Layout, Left_X + (W - Subtree_Width (N.Left)) / 2,
                Depth + 1);
      elsif N.Left /= null and then N.Right /= null then
         declare
            Lw : constant Integer := Subtree_Width (N.Left);
         begin
            Place (N.Left, Map, Layout, Left_X, Depth + 1);
            Place (N.Right, Map, Layout, Left_X + Lw + H_Gap, Depth + 1);
         end;
      end if;
   end Place;

   function Format_Svg (Root : Node_Access) return String is
      Total  : Natural := 0;
      Buffer : Unbounded_String;
      Max_X  : Integer := 0;
      Max_Y  : Integer := 0;
   begin
      Count_Nodes (Root, Total);
      declare
         Map    : Id_Map (1 .. Total);
         Layout : Layout_Array (1 .. Total);
         Next   : Positive := 1;
      begin
         Assign_Ids (Root, Map, Next);
         Place (Root, Map, Layout, Margin, 0);

         for I in Layout'Range loop
            Max_X := Integer'Max (Max_X, Layout (I).X + Box_W);
            Max_Y := Integer'Max (Max_Y, Layout (I).Y + Box_H);
         end loop;
         Max_X := Max_X + Margin;
         Max_Y := Max_Y + Margin;

         Append
           (Buffer,
            "<svg xmlns=""http://www.w3.org/2000/svg"" width="""
            & Trim_Positive (Positive (Max_X))
            & """ height="""
            & Trim_Positive (Positive (Max_Y))
            & """>");
         Append (Buffer, ASCII.LF);

         --  Edges first (under boxes)
         for I in Map'Range loop
            declare
               N : constant Node_Access := Map (I);
               X1 : constant Integer := Layout (I).X + Box_W / 2;
               Y1 : constant Integer := Layout (I).Y + Box_H;
            begin
               if N.Left /= null then
                  declare
                     Cid : constant Positive := Find_Id (Map, N.Left);
                     X2  : constant Integer :=
                       Layout (Cid).X + Box_W / 2;
                     Y2  : constant Integer := Layout (Cid).Y;
                  begin
                     Append
                       (Buffer,
                        "  <line x1="""
                        & Trim_Positive (Positive (X1))
                        & """ y1="""
                        & Trim_Positive (Positive (Y1))
                        & """ x2="""
                        & Trim_Positive (Positive (X2))
                        & """ y2="""
                        & Trim_Positive (Positive (Y2))
                        & """ stroke=""black""/>");
                     Append (Buffer, ASCII.LF);
                  end;
               end if;
               if N.Right /= null then
                  declare
                     Cid : constant Positive := Find_Id (Map, N.Right);
                     X2  : constant Integer :=
                       Layout (Cid).X + Box_W / 2;
                     Y2  : constant Integer := Layout (Cid).Y;
                  begin
                     Append
                       (Buffer,
                        "  <line x1="""
                        & Trim_Positive (Positive (X1))
                        & """ y1="""
                        & Trim_Positive (Positive (Y1))
                        & """ x2="""
                        & Trim_Positive (Positive (X2))
                        & """ y2="""
                        & Trim_Positive (Positive (Y2))
                        & """ stroke=""black""/>");
                     Append (Buffer, ASCII.LF);
                  end;
               end if;
            end;
         end loop;

         for I in Map'Range loop
            declare
               Lbl : constant String := Escape_Xml (Node_Label (Map (I)));
               X   : constant Integer := Layout (I).X;
               Y   : constant Integer := Layout (I).Y;
               TX  : constant Integer := X + Box_W / 2;
               TY  : constant Integer := Y + Box_H / 2 + 4;
            begin
               Append
                 (Buffer,
                  "  <rect x="""
                  & Trim_Positive (Positive (X))
                  & """ y="""
                  & Trim_Positive (Positive (Y))
                  & """ width="""
                  & Trim_Positive (Positive (Box_W))
                  & """ height="""
                  & Trim_Positive (Positive (Box_H))
                  & """ fill=""white"" stroke=""black""/>");
               Append (Buffer, ASCII.LF);
               Append
                 (Buffer,
                  "  <text x="""
                  & Trim_Positive (Positive (TX))
                  & """ y="""
                  & Trim_Positive (Positive (TY))
                  & """ text-anchor=""middle"" font-family=""sans-serif"""
                  & " font-size=""12"">"
                  & Lbl
                  & "</text>");
               Append (Buffer, ASCII.LF);
            end;
         end loop;

         Append (Buffer, "</svg>");
         return To_String (Buffer);
      end;
   end Format_Svg;

   function Format_Tree
     (Root : Node_Access; Fmt : Output_Format) return String
   is
   begin
      case Fmt is
         when Mermaid =>
            return Format_Mermaid (Root);
         when Markdown =>
            return Format_Markdown (Root);
         when Dot =>
            return Format_Dot (Root);
         when Svg =>
            return Format_Svg (Root);
      end case;
   end Format_Tree;

   procedure Write_To_File
     (Root : Node_Access;
      Fmt  : Output_Format;
      Path : String)
   is
      File : Ada.Text_IO.File_Type;
      Text : constant String := Format_Tree (Root, Fmt);
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put (File, Text);
      Ada.Text_IO.Close (File);
   end Write_To_File;

   procedure Write_To_Stdout
     (Root : Node_Access; Fmt : Output_Format)
   is
      Text : constant String := Format_Tree (Root, Fmt);
   begin
      Ada.Text_IO.Put (Ada.Text_IO.Standard_Output, Text);
      if Text'Length = 0
        or else Text (Text'Last) /= ASCII.LF
      then
         Ada.Text_IO.New_Line (Ada.Text_IO.Standard_Output);
      end if;
   end Write_To_Stdout;

end Expr_Parser;
