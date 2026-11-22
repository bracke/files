--  What the suite reaches of Files.Application.Settings_Keys that is not part of its interface.
package Files.Application.Settings_Keys.Testing is

   --  Capture the snapshot-relevant settings for caching.
   --
   --  @param Settings Settings model to read.
   --  @return The snapshot-input key for Settings.
   function Snapshot_Settings_Key_Of
     (Settings : Files.Settings.Settings_Model)
      return Snapshot_Settings_Key;

end Files.Application.Settings_Keys.Testing;
