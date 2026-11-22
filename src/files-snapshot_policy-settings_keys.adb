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
         Labels               => Files.Settings.Path_References.Path_Labels (Settings),
         Path_Stamp           => Files.Settings.Path_References.Path_Stamp (Settings));
   end Snapshot_Settings_Key_Of;

   procedure Update_Key
     (Key      : in out Snapshot_Settings_Key;
      Settings : Files.Settings.Settings_Model) is
   begin
      Key.Show_File_Extensions := Settings.Show_File_Extensions;
      Key.Show_Used_Space := Settings.Show_Used_Space;
      Key.Show_Space_Bar := Settings.Show_Space_Bar;
      Key.Theme := Settings.Theme;
      Key.Icon_Theme := Settings.Icon_Theme;
      Key.Column_Visible := Settings.Column_Visible;
      Key.Column_Widths := Settings.Column_Widths;
      Key.Column_Order := Settings.Column_Order;
      Key.Group_By := Settings.Group_By;
      if not Same_Path_References (Settings, Key) then
         Key.Favorite_Paths := Files.Settings.Path_References.Favorite_Paths (Settings);
         Key.Labels := Files.Settings.Path_References.Path_Labels (Settings);
      end if;
      Key.Path_Stamp := Files.Settings.Path_References.Path_Stamp (Settings);
   end Update_Key;

   function Same_Snapshot_Settings
     (Settings : Files.Settings.Settings_Model;
      Key      : Snapshot_Settings_Key)
      return Boolean is
   begin
      --  Field by field in place: building a key copies the favorites and
      --  labels, and this is asked on every frame.
      return Same_Row_Settings (Settings, Key)
        and then Settings.Show_File_Extensions = Key.Show_File_Extensions
        and then Settings.Theme = Key.Theme
        and then Files.Icon_Themes."=" (Settings.Icon_Theme, Key.Icon_Theme)
        and then Settings.Show_Used_Space = Key.Show_Used_Space
        and then Settings.Show_Space_Bar = Key.Show_Space_Bar
        and then Files.Preference_Types."=" (Settings.Column_Visible, Key.Column_Visible)
        and then Files.Preference_Types."=" (Settings.Column_Widths, Key.Column_Widths)
        and then Files.Preference_Types."=" (Settings.Column_Order, Key.Column_Order)
        and then Same_Path_References (Settings, Key);
   end Same_Snapshot_Settings;

   function Same_Row_Settings
     (Settings : Files.Settings.Settings_Model;
      Key      : Snapshot_Settings_Key)
      return Boolean is
     (Files.Preference_Types."=" (Settings.Group_By, Key.Group_By)
      --  Grouped by label, a label moves its row between bands.
      and then (Files.Preference_Types."/=" (Settings.Group_By, Files.Preference_Types.Group_By_Label)
                or else Same_Path_References (Settings, Key)));

   function Same_Path_References
     (Settings : Files.Settings.Settings_Model;
      Key      : Snapshot_Settings_Key)
      return Boolean is
     (Files.Settings.Path_References.Path_Stamp (Settings) = Key.Path_Stamp
      or else (Files.Settings.Path_References.Same_Favorites (Settings, Key.Favorite_Paths)
               and then Files.Settings.Path_References.Same_Labels (Settings, Key.Labels)));

end Files.Snapshot_Policy.Settings_Keys;
