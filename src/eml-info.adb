with Eml_Config;
with Eml_Git_Commit;

package body Eml.Info is

   function Program_Name return String is
   begin
      return "eml";
   end Program_Name;

   function Author return String is
   begin
      return "Stefano Anelli";
   end Author;

   function Version return String is
   begin
      return Eml_Config.Crate_Version;
   end Version;

   function Git_Commit return String is
   begin
      return Eml_Git_Commit.Commit;
   end Git_Commit;

   function Major_Minor_Version return String is
      V    : constant String := Version;
      Dots : Natural := 0;
   begin
      for I in V'Range loop
         if V (I) = '.' then
            Dots := Dots + 1;
            if Dots = 2 then
               return V (V'First .. I - 1);
            end if;
         end if;
      end loop;
      return V;
   end Major_Minor_Version;

   function Banner_Line return String is
   begin
      return
        "EML compiler and interpreter - v"
        & Major_Minor_Version
        & "."
        & Git_Commit
        & " - by "
        & Author;
   end Banner_Line;

end Eml.Info;
