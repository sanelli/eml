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

end Eml.Info;
