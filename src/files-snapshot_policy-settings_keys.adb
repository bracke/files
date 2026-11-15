with Files.Settings.Path_References;

package body Files.Snapshot_Policy.Settings_Keys is

   use type Files.Settings.Theme_Choice;

   function Snapshot_Settings_Key_Of
     (Settings : Files.Settings.Settings_Model)
      return Snapshot_Settings_Key is
   begin
      return
        (Show_File_Extensions => Settings.Show_File_Extensions,
         Show_Used_Space      => Settings.Show_Used_Space,
         Show_Space_Bar       => Settings.Show_Space_Bar,
         Theme                => Settings.Theme,
         Icon_Theme           => Settings.Icon_Theme,
         Column_Visible       => Settings.Column_Visible,
         Column_Widths        => Settings.Column_Widths,
         Column_Order         => Settings.Column_Order,
         Group_By             => Settings.Group_By,
         Favorite_Paths       => Files.Settings.Path_References.Favorite_Paths (Settings),
         Labels               => Files.Settings.Path_References.Path_Labels (Settings));
   end Snapshot_Settings_Key_Of;

   function Same_Snapshot_Settings
     (Settings : Files.Settings.Settings_Model;
      Key      : Snapshot_Settings_Key)
      return Boolean is
   begin
      --  Field by field in place: building a key copies the favorites and
      --  labels, and this is asked on every frame.
      return Same_Row_Settings (Settings, Key)
        and then Settings.Show_Used_Space = Key.Show_Used_Space
        and then Settings.Show_Space_Bar = Key.Show_Space_Bar
        and then Files.Types."=" (Settings.Column_Visible, Key.Column_Visible)
        and then Files.Types."=" (Settings.Column_Widths, Key.Column_Widths)
        and then Files.Types."=" (Settings.Column_Order, Key.Column_Order);
   end Same_Snapshot_Settings;

   function Same_Row_Settings
     (Settings : Files.Settings.Settings_Model;
      Key      : Snapshot_Settings_Key)
      return Boolean is
   begin
      return Settings.Show_File_Extensions = Key.Show_File_Extensions
        and then Settings.Theme = Key.Theme
        and then Files.Icon_Themes."=" (Settings.Icon_Theme, Key.Icon_Theme)
        and then Files.Types."=" (Settings.Group_By, Key.Group_By)
        and then Files.Settings.Path_References.Same_Favorites (Settings, Key.Favorite_Paths)
        and then Files.Settings.Path_References.Same_Labels (Settings, Key.Labels);
   end Same_Row_Settings;

end Files.Snapshot_Policy.Settings_Keys;
