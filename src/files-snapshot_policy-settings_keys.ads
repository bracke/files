with Files.Preference_Types;
with Files.Icon_Themes;
with Files.Settings;

--  The settings a view snapshot is built from, captured so the window can
--  tell whether its cached snapshot still shows them (Action_For's
--  Same_Settings and Same_Row_Settings).
package Files.Snapshot_Policy.Settings_Keys is

   --  The exact subset of the settings that Build_Snapshot reads. The render
   --  layer caches this and reuses the cached view snapshot while it still
   --  matches, so the snapshot rebuilds automatically on a theme, column,
   --  visibility, favorite or label change without any explicit invalidation.
   --  Keep this in step with the Settings.* reads in Files.Rendering's
   --  Build_Snapshot_Into (files-rendering-build_snapshot_into*.adb).
   type Snapshot_Settings_Key is record
      Show_File_Extensions : Boolean := False;
      Show_Used_Space      : Boolean := False;
      Show_Space_Bar       : Boolean := False;
      Theme                : Files.Settings.Theme_Choice := Files.Settings.Theme_Dark;
      Icon_Theme           : Files.Icon_Themes.Icon_Theme := Files.Icon_Themes.Basic;
      Column_Visible       : Files.Preference_Types.Detail_Column_Visibility :=
        Files.Preference_Types.Default_Detail_Column_Visibility;
      Column_Widths        : Files.Preference_Types.Detail_Column_Widths :=
        Files.Preference_Types.Default_Detail_Column_Widths;
      Column_Order         : Files.Preference_Types.Detail_Column_Order :=
        Files.Preference_Types.Default_Detail_Column_Order;
      Group_By             : Files.Preference_Types.Group_Mode := Files.Preference_Types.No_Grouping;
      Favorite_Paths       : Files.Settings.String_Vectors.Vector;
      Labels               : Files.Settings.Path_Label_Vectors.Vector;
   end record;

   --  Capture the snapshot-relevant settings for caching.
   --
   --  @param Settings Settings model to read.
   --  @return The snapshot-input key for Settings.
   function Snapshot_Settings_Key_Of
     (Settings : Files.Settings.Settings_Model)
      return Snapshot_Settings_Key;

   --  Whether the settings a snapshot's rows read (favorites, labels, the
   --  grouping, how names and icons show) are still those in Key: the detail
   --  columns' widths, order and visibility and the free-space display are
   --  drawn from the snapshot's header, so a column drag keeps the rows.
   --
   --  @param Settings Settings model to test.
   --  @param Key Previously captured snapshot-input key.
   --  @return True when the row inputs equal Key's.
   function Same_Row_Settings
     (Settings : Files.Settings.Settings_Model;
      Key      : Snapshot_Settings_Key)
      return Boolean;

   --  Whether Settings still yields the snapshot-input key Key, i.e. nothing the
   --  view snapshot depends on has changed. Compares in place without building a
   --  new key, so it is cheap enough for the per-frame render reuse check.
   --
   --  @param Settings Settings model to test.
   --  @param Key Previously captured snapshot-input key.
   --  @return True when Settings's snapshot inputs equal Key.
   function Same_Snapshot_Settings
     (Settings : Files.Settings.Settings_Model;
      Key      : Snapshot_Settings_Key)
      return Boolean;

end Files.Snapshot_Policy.Settings_Keys;
