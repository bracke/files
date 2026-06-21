with Ada.Characters.Handling;
with Ada.Strings.Fixed;

package body Files.Types is

   function To_Lower (Text : String) return String is
      Result : String (Text'Range);
   begin
      for Index in Text'Range loop
         Result (Index) := Ada.Characters.Handling.To_Lower (Text (Index));
      end loop;

      return Result;
   end To_Lower;

   function Contains_Case_Insensitive
     (Haystack : String;
      Needle   : String)
      return Boolean
   is
   begin
      if Needle = "" then
         return True;
      end if;

      return Ada.Strings.Fixed.Index (To_Lower (Haystack), To_Lower (Needle)) > 0;
   end Contains_Case_Insensitive;

end Files.Types;
