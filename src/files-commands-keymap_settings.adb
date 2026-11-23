with Ada.Strings.Unbounded;

package body Files.Commands.Keymap_Settings is

   use Ada.Strings.Unbounded;

   function Keymap_Of (Overrides : Files.Settings.Shortcut_Override_Vectors.Vector) return Keymap is
      Result : Keymap := Default_Keymap;

      --  The command an entry names, or No_Command when it is dropped.
      function Command_Of (Entry_Value : Files.Settings.Shortcut_Override) return Command_Id is
         Id : constant Command_Id := Id_For_Identifier (To_String (Entry_Value.Command));
      begin
         if Id /= No_Command and then Is_Valid_Shortcut_Text (To_String (Entry_Value.Combo)) then
            return Id;
         else
            return No_Command;
         end if;
      end Command_Of;
   begin
      --  Overrides were merged command by command (another process's and
      --  this one's), so they may break the keymap's rules: two commands on
      --  one chord, or a chord equal to the default stored as an override.
      --  First every overridden command lets its chords go, so a chord one
      --  rebind frees is free for another; then each is bound again by the
      --  rules (Rebind). One that would take a chord another command holds
      --  keeps its default binding instead, or none when that is taken too.
      for Entry_Value of Overrides loop
         if Command_Of (Entry_Value) /= No_Command then
            Set_Shortcut_Override (Result, Command_Of (Entry_Value), (others => <>));
         end if;
      end loop;
      for Entry_Value of Overrides loop
         declare
            Id : constant Command_Id := Command_Of (Entry_Value);
         begin
            if Id /= No_Command
              and then Rebind (Result, Id, Parse_Shortcut (To_String (Entry_Value.Combo))) = Conflict
            then
               declare
                  --  Conflict too: it stays unbound, as the first pass left it.
                  Defaulted : constant Rebind_Outcome := Rebind (Result, Id, Default_Shortcut_For (Id));
                  pragma Unreferenced (Defaulted);
               begin
                  null;
               end;
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
