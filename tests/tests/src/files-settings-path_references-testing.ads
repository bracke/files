--  Test seam of Files.Settings.Path_References: match stored paths as a
--  host whose volumes fold names (Windows) does, on any host.
package Files.Settings.Path_References.Testing is

   --  From now on (Fold => True) stored paths are matched without regard to
   --  case, as on Windows; Fold => False puts back this host's own rule.
   --
   --  @param Fold Whether to match as a folding host.
   procedure Simulate_Folding_Host (Fold : Boolean);

   --  Assign Label to Path, replacing any existing label. Passing No_Label
   --  clears Path's label by removing its stored entry. The empty path is
   --  ignored.
   --
   --  @param Settings Settings model updated in place.
   --  @param Path Full item or folder path to label.
   --  @param Label Color label to assign, or No_Label to clear.
   procedure Set_Label
     (Settings : in out Settings_Model;
      Path     : String;
      Label    : Files.Preference_Types.Color_Label);

end Files.Settings.Path_References.Testing;
