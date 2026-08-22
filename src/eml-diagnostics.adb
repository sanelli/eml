with Ada.Text_IO;

package body Eml.Diagnostics is

   Red_On     : constant String := ASCII.ESC & "[31m";
   Red_Off    : constant String := ASCII.ESC & "[0m";
   Yellow_On  : constant String := ASCII.ESC & "[33m";
   Yellow_Off : constant String := ASCII.ESC & "[0m";

   function Id_Image (Id : Diagnostic_Id) return String is
      Raw : constant String := Natural'Image (Id);
      D   : constant String :=
        (if Raw (Raw'First) = ' ' then Raw (Raw'First + 1 .. Raw'Last)
         else Raw);
      Pad : String (1 .. 5);
   begin
      if D'Length >= 5 then
         return D (D'Last - 4 .. D'Last);
      end if;
      Pad := [others => '0'];
      return Pad (1 .. 5 - D'Length) & D;
   end Id_Image;

   function Severity_Of (Id : Diagnostic_Id) return Severity is
   begin
      case Id is
         when PP_Unused_Variable_Warn =>
            return Warning;
         when others =>
            return Error;
      end case;
   end Severity_Of;

   function Message
     (Id     : Diagnostic_Id;
      Param1 : String := "";
      Param2 : String := "") return String
   is
      Dummy2 : constant String := Param2;
      pragma Unreferenced (Dummy2);
   begin
      case Id is
         when CLI_Missing_Command =>
            return
              "missing command "
              & "(expected help, preproc, tokenize, parse, compile, or run)";
         when CLI_Missing_Command_With_Arg =>
            return
              "missing command "
              & "(expected help, preproc, tokenize, parse, compile, or run); "
              & "got '"
              & Param1
              & "'";
         when CLI_Unexpected_Argument =>
            return "unexpected argument '" & Param1 & "'";
         when CLI_Repeated_Input =>
            return "repeated --input/-i";
         when CLI_Repeated_Output =>
            return "repeated --output/-o";
         when CLI_Repeated_Output_Format =>
            return "repeated --output-format/-of";
         when CLI_Repeated_Input_Format =>
            return "repeated --input-format/-if";
         when CLI_Repeated_Warn =>
            return "repeated --warn/-w";
         when CLI_Missing_Flag_Value =>
            return "missing value for " & Param1;
         when CLI_Invalid_Var_Binding =>
            return
              "invalid --var/-v binding '"
              & Param1
              & "' (expected $NAME=EXPRESSION)";
         when CLI_Repeated_Var =>
            return "repeated --var/-v for " & Param1;
         when CLI_Too_Many_Vars =>
            return "too many --var/-v bindings";
         when CLI_Unknown_Warn_Mode =>
            return
              "unknown warn mode '"
              & Param1
              & "' (expected default, none, or error)";
         when CLI_Unknown_Help_Topic =>
            return
              "unknown help topic '" & Param1
              & "' (try: eml help preproc)";
         when CLI_Unknown_Command =>
            return
              "unknown command '"
              & Param1
              & "' (expected help, preproc, tokenize, parse, compile, or run)";
         when CLI_Run_Rejects_Output =>
            return "run does not accept --output/-o";
         when CLI_Run_Rejects_Output_Format =>
            return "run does not accept --output-format/-of";
         when CLI_Repeated_Function_Name =>
            return "repeated --function-name/-fn";
         when CLI_Invalid_Function_Name =>
            return
              "invalid --function-name/-fn '"
              & Param1
              & "' (expected a C/JS identifier)";
         when CLI_Function_Name_Not_Allowed =>
            return
              "--function-name/-fn is only allowed for "
              & "compile -of js or clib";
         when CLI_Repeated_Emit_Eml =>
            return "repeated --emit-eml";
         when CLI_Emit_Eml_Not_Allowed =>
            return
              "--emit-eml is only allowed for compile -of clib";
         when CLI_Input_Format_Required =>
            return
              "missing --input-format/-if "
              & "(required when --input/-i is omitted)";
         when CLI_Unknown_Input_Format =>
            return
              "unknown input format '"
              & Param1
              & "' (expected mxeml, teml, eml, or beml)";
         when CLI_Unknown_Output_Format =>
            return "unknown output format '" & Param1 & "' for " & Param2;
         when CLI_Unknown_Extension =>
            return
              "unknown input extension '"
              & Param1
              & "' (expected "
              & Param2
              & ")";
         when CLI_Format_Not_Allowed =>
            return
              Param1 & " format '" & Param2
              & "' is not allowed for this command";
         when CLI_Output_Extension_Mismatch =>
            return
              "output must end with "
              & Param1
              & " for format "
              & Param2;
         when CLI_Preproc_Output_Mismatch =>
            return
              "preproc output format must match input format (got "
              & Param1
              & ", expected "
              & Param2
              & ")";
         when CLI_Same_Format_Compile =>
            return
              "compile output format matches input format ("
              & Param1
              & ")";
         when CLI_IO_Error =>
            return Param1;
         when CLI_Unexpected_Format_Flag =>
            return "unexpected --format/-f (use --output-format/-of)";

         when PP_Unbound_Variable =>
            return "undefined variable " & Param1;
         when PP_Unused_Variable_Warn =>
            return "unused variable " & Param1;
         when PP_Unused_Variable_Error =>
            return "unused variable " & Param1;

         when MX_Unknown_Identifier =>
            return "unknown identifier '" & Param1 & "'";
         when MX_Unexpected_Character =>
            return "unexpected character '" & Param1 & "'";

         when TM_Unexpected_Character =>
            return "unexpected character '" & Param1 & "'";

         when SE_Unexpected_Character =>
            return "unexpected character '" & Param1 & "'";
         when SE_Unknown_Identifier =>
            return "unknown identifier '" & Param1 & "'";

         when MX_Unexpected_EOI =>
            return "unexpected end of input";
         when MX_Expected_RParen =>
            return "expected ')'";
         when MX_Expected_LParen_After_Func =>
            return "expected '(' after function '" & Param1 & "'";
         when MX_Unexpected_RParen =>
            return "unexpected token ')'";
         when MX_Unexpected_Token =>
            return "unexpected token '" & Param1 & "'";
         when MX_Unexpected_After_Expr =>
            return "unexpected token after expression";
         when MX_Expected_Comma =>
            return "expected ',' in eml argument list";
         when MX_Unexpected_Comma =>
            return "unexpected ','";

         when TM_Unexpected_EOI =>
            return "unexpected end of input";
         when TM_Expected_RParen =>
            return "expected ')'";
         when TM_Expected_LParen_After_Eml =>
            return "expected '(' after eml";
         when TM_Expected_Comma =>
            return "expected ',' in eml argument list";
         when TM_Unexpected_Token =>
            return "unexpected token '" & Param1 & "'";
         when TM_Unexpected_After_Expr =>
            return "unexpected token after expression";

         when SE_Unexpected_EOI =>
            return "unexpected end of input";
         when SE_Stack_Underflow =>
            return "stack underflow at EML";
         when SE_Stack_Not_Single =>
            return "stack depth is not 1 at end of program";
         when SE_Unexpected_Token =>
            return "unexpected token '" & Param1 & "'";

         when BE_Too_Short =>
            return "BEML file too short";
         when BE_Bad_Magic =>
            return "invalid BEML magic";
         when BE_Bad_Version =>
            return "unsupported BEML version";
         when BE_Bad_Timestamp =>
            return "invalid BEML timestamp";
         when BE_Extra_Bytes =>
            return "extra bytes after BEML payload";
         when BE_Truncated =>
            return "truncated BEML payload";
         when BE_Nonzero_Pad =>
            return "nonzero padding bits in BEML code section";
         when BE_Empty_Program =>
            return "empty BEML program";
         when BE_Stack_Underflow =>
            return "stack underflow reconstructing BEML";
         when BE_Stack_Not_Single =>
            return "BEML program does not reduce to a single value";

         when RT_Stack_Underflow =>
            return "stack underflow at EML";
         when RT_Stack_Not_Single =>
            return "stack depth is not 1 after program";
         when RT_Numeric_Error =>
            return "numeric error evaluating EML";

         when others =>
            return "internal diagnostic error";
      end case;
   end Message;

   function Trim_Nat (N : Natural) return String is
      S : constant String := Natural'Image (N);
   begin
      if S'Length > 0 and then S (S'First) = ' ' then
         return S (S'First + 1 .. S'Last);
      end if;
      return S;
   end Trim_Nat;

   function Format_Line
     (Id     : Diagnostic_Id;
      Line   : Natural;
      Column : Natural;
      Param1 : String := "";
      Param2 : String := "") return String
   is
   begin
      return
        "["
        & Id_Image (Id)
        & "] "
        & Trim_Nat (Line)
        & ":"
        & Trim_Nat (Column)
        & " "
        & Message (Id, Param1, Param2);
   end Format_Line;

   function Format_Line_With_Suffix
     (Id     : Diagnostic_Id;
      Line   : Natural;
      Column : Natural;
      Param1 : String := "";
      Param2 : String := "";
      Suffix : String := "") return String
   is
   begin
      return Format_Line (Id, Line, Column, Param1, Param2) & Suffix;
   end Format_Line_With_Suffix;

   procedure Emit_Error_Line (Line : String; Use_Color : Boolean) is
   begin
      if Use_Color then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error, Red_On & Line & Red_Off);
      else
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, Line);
      end if;
   end Emit_Error_Line;

   procedure Emit_Warning_Line (Line : String; Use_Color : Boolean) is
   begin
      if Use_Color then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error, Yellow_On & Line & Yellow_Off);
      else
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, Line);
      end if;
   end Emit_Warning_Line;

end Eml.Diagnostics;
