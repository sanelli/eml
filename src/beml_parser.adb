package body Beml_Parser is

   use Eml.Diagnostics;
   use IR_Eml;

   function Parse (Ops : IR_Eml.Opcode_Array) return Parse_Result is
      Root : constant Node_Access := Unflatten (Ops);
   begin
      if Ops'Length = 0 then
         return
           (Root       => null,
            Had_Error  => True,
            Error_Id   => BE_Empty_Program,
            Error_Line => 1,
            Error_Col  => 13);
      end if;
      if Root = null then
         return
           (Root       => null,
            Had_Error  => True,
            Error_Id   => BE_Stack_Not_Single,
            Error_Line => 1,
            Error_Col  => 16 + Ops'Length);
      end if;
      return (Root => Root, others => <>);
   end Parse;

   function Parse (Ops : IR_Eml.Opcode_Array_Access) return Parse_Result is
   begin
      if Ops = null or else Ops'Length = 0 then
         return
           (Root       => null,
            Had_Error  => True,
            Error_Id   => BE_Empty_Program,
            Error_Line => 1,
            Error_Col  => 13);
      end if;
      return Parse (Ops.all);
   end Parse;

end Beml_Parser;
