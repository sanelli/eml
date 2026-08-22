--  Program identity for the startup banner.
package Eml.Info is

   function Program_Name return String;
   function Author return String;
   function Version return String;
   function Git_Commit return String;

   function Banner_Line return String;
   --  Single-line startup banner:
   --  EML compiler and interpreter - v<major>.<minor>.<commit> - by <author>

end Eml.Info;
