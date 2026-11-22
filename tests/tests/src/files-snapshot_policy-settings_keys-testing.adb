package body Files.Snapshot_Policy.Settings_Keys.Testing is

   function Snapshot_Settings_Key_Of
     (Settings : Files.Settings.Settings_Model)
      return Snapshot_Settings_Key renames Files.Snapshot_Policy.Settings_Keys.Snapshot_Settings_Key_Of;

end Files.Snapshot_Policy.Settings_Keys.Testing;
