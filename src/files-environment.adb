with Ada.Strings.Unbounded;

with Hostkit.Environment;
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

   function Is_Set (Name : String) return Boolean is
      Found : Ada.Strings.Unbounded.Unbounded_String;
   begin
      return Hostkit.Process.Environment_Value (Name, Found);
   end Is_Set;

   procedure Set (Name : String; Value : String) is
   begin
      Hostkit.Environment.Set (Name, Value);
   end Set;

   procedure Clear (Name : String) is
   begin
      Hostkit.Environment.Clear (Name);
   end Clear;

end Files.Environment;
