with Ada.Strings.Unbounded;

with Files.Commands.Keymap_Settings;

package body Files.Settings.Storage is

   use Ada.Strings.Unbounded;

   function Full_Result (Settings_Path : String) return Settings_Write_Result is
     (Success   => False,
      Durable   => False,
      Path      => To_Unbounded_String (Settings_Path),
      Error_Key => To_Unbounded_String ("error.settings.full"));

   function Unchanged_Result (Settings_Path : String) return Settings_Write_Result is
     (Success   => True,
      Durable   => True,
      Path      => To_Unbounded_String (Settings_Path),
      Error_Key => Null_Unbounded_String);

   function Write
     (Settings_Path : String;
      Settings      : in out Settings_Model)
      return Settings_Write_Result
   is
      use type Shortcut_Override_Vectors.Vector;
      Merged, Refused : Boolean;
   begin
      if Settings.Persistence_Refused then
         return
           (Success   => True,
            Durable   => False,
            Path      => To_Unbounded_String (Settings_Path),
            Error_Key => To_Unbounded_String ("error.settings.not_persisted"));
      elsif Settings_Path = "" then
         return (Success => True, Durable => True, Path => Null_Unbounded_String, Error_Key => Null_Unbounded_String);
      end if;
      Files.Commands.Keymap_Settings.Store_Shortcut_Overrides (Settings);
      declare
         Own : constant Settings_Model := Settings;
      begin
         Merge_From_File (Settings_Path, Settings, Merged, Refused);
         if Refused then
            return
              (Success   => True,
               Durable   => False,
               Path      => To_Unbounded_String (Settings_Path),
               Error_Key => To_Unbounded_String ("error.settings.changed_elsewhere"));
         elsif Merged then
            if not Loadable (Settings) then
               Settings := Own;
               return Full_Result (Settings_Path);
            elsif Settings.Shortcut_Overrides /= Own.Shortcut_Overrides then
               Files.Commands.Keymap_Settings.Apply_Shortcut_Overrides (Settings);
            end if;
         end if;
      end;
      return Save_Text (Settings_Path, To_Text (Settings));
   end Write;

   function Persist
     (Settings_Path : String;
      Settings      : in out Settings_Model;
      Taken_In      : out Boolean)
      return Settings_Write_Result
   is
      Before : constant Settings_Model := Settings;
   begin
      Taken_In := False;
      if not Loadable (Settings) then
         return Full_Result (Settings_Path);
      end if;
      declare
         Saved : constant Settings_Write_Result := Write (Settings_Path, Settings);
      begin
         Taken_In := not Same_Content (Settings, Before);
         return Saved;
      end;
   end Persist;

   function Decide_Commit
     (Current : Settings_Model;
      Updated : Settings_Model)
      return Commit_Decision is
   begin
      if Same_Content (Updated, Current) then
         return Commit_Unchanged;
      elsif not Loadable (Updated) and then Loadable (Current) then
         return Commit_Refused;
      else
         return Commit_Accepted;
      end if;
   end Decide_Commit;

end Files.Settings.Storage;
