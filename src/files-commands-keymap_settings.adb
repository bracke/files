with Ada.Strings.Unbounded;

package body Files.Commands.Keymap_Settings is

   use Ada.Strings.Unbounded;

   function Keymap_Of (Overrides : Files.Settings.Shortcut_Override_Vectors.Vector) return Keymap is
      Result : Keymap := Default_Keymap;
   begin
      for Entry_Value of Overrides loop
         declare
            Id : constant Command_Id := Id_For_Identifier (To_String (Entry_Value.Command));
         begin
            if Id /= No_Command and then Is_Valid_Shortcut_Text (To_String (Entry_Value.Combo)) then
               Set_Shortcut_Override (Result, Id, Parse_Shortcut (To_String (Entry_Value.Combo)));
            end if;
         end;
      end loop;
      return Result;
   end Keymap_Of;

   function Overrides_Of (Map : Keymap) return Files.Settings.Shortcut_Override_Vectors.Vector is
      Result : Files.Settings.Shortcut_Override_Vectors.Vector;
   begin
      for Id in Registered_Command_Id loop
         declare
            Is_Set : Boolean;
            Value  : constant Shortcut := Shortcut_Override (Map, Id, Is_Set);
         begin
            if Is_Set then
               Result.Append
                 (Files.Settings.Shortcut_Override'
                    (Command => To_Unbounded_String (Identifier (Id)),
                     Combo   => To_Unbounded_String (Shortcut_Text (Value))));
            end if;
         end;
      end loop;
      return Result;
   end Overrides_Of;

   procedure Apply_Shortcut_Overrides (Settings : in out Files.Settings.Settings_Model) is
   begin
      Set_Live_Keymap (Keymap_Of (Settings.Shortcut_Overrides));
      Settings.Shortcut_Overrides := Overrides_Of (Live_Keymap);
   end Apply_Shortcut_Overrides;

end Files.Commands.Keymap_Settings;
