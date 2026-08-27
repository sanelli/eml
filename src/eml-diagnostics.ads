--  Central catalog of diagnostic IDs and message text.
package Eml.Diagnostics is

   type Severity is (Warning, Error);

   subtype Diagnostic_Id is Natural range 1 .. 99999;

   --  CLI (00001-00099)
   CLI_Missing_Command              : constant Diagnostic_Id := 1;
   CLI_Missing_Command_With_Arg     : constant Diagnostic_Id := 2;
   CLI_Unexpected_Argument            : constant Diagnostic_Id := 3;
   CLI_Repeated_Input                 : constant Diagnostic_Id := 4;
   CLI_Repeated_Output                : constant Diagnostic_Id := 5;
   CLI_Repeated_Output_Format         : constant Diagnostic_Id := 6;
   CLI_Repeated_Input_Format          : constant Diagnostic_Id := 7;
   CLI_Repeated_Warn                  : constant Diagnostic_Id := 8;
   CLI_Missing_Flag_Value             : constant Diagnostic_Id := 9;
   CLI_Invalid_Var_Binding            : constant Diagnostic_Id := 10;
   CLI_Repeated_Var                   : constant Diagnostic_Id := 11;
   CLI_Too_Many_Vars                  : constant Diagnostic_Id := 12;
   CLI_Unknown_Warn_Mode              : constant Diagnostic_Id := 13;
   CLI_Unknown_Help_Topic             : constant Diagnostic_Id := 14;
   CLI_Unknown_Command                : constant Diagnostic_Id := 15;
   CLI_Input_Format_Required          : constant Diagnostic_Id := 16;
   CLI_Unknown_Input_Format           : constant Diagnostic_Id := 17;
   CLI_Unknown_Output_Format          : constant Diagnostic_Id := 18;
   CLI_Unknown_Extension              : constant Diagnostic_Id := 19;
   CLI_Format_Not_Allowed             : constant Diagnostic_Id := 20;
   CLI_Output_Extension_Mismatch      : constant Diagnostic_Id := 21;
   CLI_Preproc_Output_Mismatch        : constant Diagnostic_Id := 22;
   CLI_Same_Format_Compile            : constant Diagnostic_Id := 23;
   CLI_IO_Error                       : constant Diagnostic_Id := 24;
   CLI_Unexpected_Format_Flag         : constant Diagnostic_Id := 25;
   CLI_Run_Rejects_Output             : constant Diagnostic_Id := 26;
   CLI_Run_Rejects_Output_Format      : constant Diagnostic_Id := 27;
   CLI_Repeated_Function_Name         : constant Diagnostic_Id := 28;
   CLI_Invalid_Function_Name          : constant Diagnostic_Id := 29;
   CLI_Function_Name_Not_Allowed      : constant Diagnostic_Id := 30;
   CLI_Repeated_Emit_Eml              : constant Diagnostic_Id := 31;
   CLI_Emit_Eml_Not_Allowed           : constant Diagnostic_Id := 32;
   CLI_Repeated_Framework             : constant Diagnostic_Id := 33;
   CLI_Invalid_Framework              : constant Diagnostic_Id := 34;
   CLI_Framework_Not_Allowed          : constant Diagnostic_Id := 35;
   CLI_Repeated_No_Companion_Project  : constant Diagnostic_Id := 36;
   CLI_No_Companion_Project_Not_Allowed : constant Diagnostic_Id := 37;
   CLI_Dll_Requires_Output            : constant Diagnostic_Id := 38;
   CLI_Dotnet_Not_Found               : constant Diagnostic_Id := 39;
   CLI_Dotnet_Build_Failed            : constant Diagnostic_Id := 40;

   --  Preprocessor (00100-00199)
   PP_Unbound_Variable                : constant Diagnostic_Id := 100;
   PP_Unused_Variable_Warn            : constant Diagnostic_Id := 101;
   PP_Unused_Variable_Error           : constant Diagnostic_Id := 102;

   --  Mxeml / expr tokenizer (00200-00249)
   MX_Unknown_Identifier              : constant Diagnostic_Id := 200;
   MX_Unexpected_Character            : constant Diagnostic_Id := 201;

   --  Nested teml tokenizer (00250-00269)
   TM_Unexpected_Character            : constant Diagnostic_Id := 250;

   --  Stack eml tokenizer (00270-00289)
   SE_Unexpected_Character            : constant Diagnostic_Id := 270;
   SE_Unknown_Identifier              : constant Diagnostic_Id := 271;

   --  Mxeml parser (00300-00349)
   MX_Unexpected_EOI                  : constant Diagnostic_Id := 300;
   MX_Expected_RParen                 : constant Diagnostic_Id := 301;
   MX_Expected_LParen_After_Func      : constant Diagnostic_Id := 302;
   MX_Unexpected_RParen               : constant Diagnostic_Id := 303;
   MX_Unexpected_Token                : constant Diagnostic_Id := 304;
   MX_Unexpected_After_Expr           : constant Diagnostic_Id := 305;
   MX_Expected_Comma                  : constant Diagnostic_Id := 306;
   MX_Unexpected_Comma                : constant Diagnostic_Id := 307;

   --  Nested teml parser (00350-00369)
   TM_Unexpected_EOI                  : constant Diagnostic_Id := 350;
   TM_Expected_RParen                 : constant Diagnostic_Id := 351;
   TM_Expected_LParen_After_Eml       : constant Diagnostic_Id := 352;
   TM_Expected_Comma                  : constant Diagnostic_Id := 353;
   TM_Unexpected_Token                : constant Diagnostic_Id := 354;
   TM_Unexpected_After_Expr           : constant Diagnostic_Id := 355;

   --  Stack eml parser (00370-00389)
   SE_Unexpected_EOI                  : constant Diagnostic_Id := 370;
   SE_Stack_Underflow                 : constant Diagnostic_Id := 371;
   SE_Stack_Not_Single                : constant Diagnostic_Id := 372;
   SE_Unexpected_Token                : constant Diagnostic_Id := 373;

   --  BEML reader/parser (00400-00499)
   BE_Too_Short                       : constant Diagnostic_Id := 400;
   BE_Bad_Magic                       : constant Diagnostic_Id := 401;
   BE_Bad_Version                     : constant Diagnostic_Id := 402;
   BE_Bad_Timestamp                   : constant Diagnostic_Id := 403;
   BE_Extra_Bytes                     : constant Diagnostic_Id := 404;
   BE_Truncated                       : constant Diagnostic_Id := 405;
   BE_Nonzero_Pad                     : constant Diagnostic_Id := 406;
   BE_Empty_Program                   : constant Diagnostic_Id := 407;
   BE_Stack_Underflow                 : constant Diagnostic_Id := 408;
   BE_Stack_Not_Single                : constant Diagnostic_Id := 409;

   --  Runtime / interpreter (00500-00599)
   RT_Stack_Underflow                 : constant Diagnostic_Id := 500;
   RT_Stack_Not_Single                : constant Diagnostic_Id := 501;
   RT_Numeric_Error                   : constant Diagnostic_Id := 502;

   function Id_Image (Id : Diagnostic_Id) return String;
   --  Five-digit zero-padded id (e.g. 00001).

   function Severity_Of (Id : Diagnostic_Id) return Severity;

   function Message
     (Id     : Diagnostic_Id;
      Param1 : String := "";
      Param2 : String := "") return String;
   --  Description text only (no id or location).

   function Format_Line
     (Id     : Diagnostic_Id;
      Line   : Natural;
      Column : Natural;
      Param1 : String := "";
      Param2 : String := "") return String;
   --  [00001] line:column description

   function Format_Line_With_Suffix
     (Id     : Diagnostic_Id;
      Line   : Natural;
      Column : Natural;
      Param1 : String := "";
      Param2 : String := "";
      Suffix : String := "") return String;
   --  Format_Line plus optional suffix (e.g. from $VAR).

   procedure Emit_Error_Line
     (Line   : String;
      Use_Color : Boolean);

   procedure Emit_Warning_Line
     (Line   : String;
      Use_Color : Boolean);

end Eml.Diagnostics;
