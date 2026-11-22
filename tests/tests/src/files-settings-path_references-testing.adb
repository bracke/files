package body Files.Settings.Path_References.Testing is

   procedure Simulate_Folding_Host (Fold : Boolean) is
   begin
      Folds_Paths := Fold or else Hostkit.Host."=" (Hostkit.Host.Current, Hostkit.Host.Windows);
   end Simulate_Folding_Host;

   procedure Set_Label
     (Settings : in out Settings_Model;
      Path     : String;
      Label    : Files.Preference_Types.Color_Label) renames Files.Settings.Path_References.Set_Label;

end Files.Settings.Path_References.Testing;
