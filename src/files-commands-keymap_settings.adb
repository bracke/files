with Ada.Strings.Unbounded;

package body Files.Commands.Keymap_Settings is

   use Ada.Strings.Unbounded;

   procedure Store_Shortcut_Overrides (Settings : in out Files.Settings.Settings_Model) is
   begin
      Settings.Shortcut_Overrides.Clear;
      for Id in Registered_Command_Id loop
         declare
            Is_Set : Boolean;
            Value  : constant Shortcut := Shortcut_Override (Id, Is_Set);
         begin
            if Is_Set then
               Settings.Shortcut_Overrides.Append
                 (Files.Settings.Shortcut_Override'
                    (Command => To_Unbounded_String (Identifier (Id)),
                     Combo   => To_Unbounded_String (Shortcut_Text (Value))));
            end if;
         end;
      end loop;
   end Store_Shortcut_Overrides;

   procedure Apply_Shortcut_Overrides (Settings : in out Files.Settings.Settings_Model) is
   begin
      Reset_Shortcut_Overrides;
      for Entry_Value of Settings.Shortcut_Overrides loop
         declare
            Id : constant Command_Id := Id_For_Identifier (To_String (Entry_Value.Command));
         begin
            if Id /= No_Command and then Is_Valid_Shortcut_Text (To_String (Entry_Value.Combo)) then
               Set_Shortcut_Override (Id, Parse_Shortcut (To_String (Entry_Value.Combo)));
            end if;
         end;
      end loop;
      Store_Shortcut_Overrides (Settings);
   end Apply_Shortcut_Overrides;

end Files.Commands.Keymap_Settings;
