with Ada.Text_IO;

package body Elm.CLI is

   function Identity return String is
   begin
      return "elm";
   end Identity;

   procedure Run is
   begin
      Ada.Text_IO.Put_Line (Identity);
   end Run;

end Elm.CLI;
