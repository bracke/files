with Ada.Strings.Unbounded;

with Hostkit.Process;

package body Files.Environment is

   function Value (Name : String) return String is
      Found : Ada.Strings.Unbounded.Unbounded_String;
   begin
      if Hostkit.Process.Environment_Value (Name, Found) then
         return Ada.Strings.Unbounded.To_String (Found);
      end if;
      return "";
   end Value;

end Files.Environment;
