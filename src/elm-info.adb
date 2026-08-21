with Elm_Config;
with Elm_Git_Commit;

package body Elm.Info is

   function Program_Name return String is
   begin
      return "elm";
   end Program_Name;

   function Author return String is
   begin
      return "Stefano Anelli";
   end Author;

   function Version return String is
   begin
      return Elm_Config.Crate_Version;
   end Version;

   function Git_Commit return String is
   begin
      return Elm_Git_Commit.Commit;
   end Git_Commit;

end Elm.Info;
