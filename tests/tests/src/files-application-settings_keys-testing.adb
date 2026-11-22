package body Files.Application.Settings_Keys.Testing is

   function Snapshot_Settings_Key_Of
     (Settings : Files.Settings.Settings_Model)
      return Snapshot_Settings_Key renames Files.Application.Settings_Keys.Snapshot_Settings_Key_Of;

end Files.Application.Settings_Keys.Testing;
