package body Files.Settings.Path_References.Testing is

   procedure Simulate_Folding_Host (Fold : Boolean) is
   begin
      Folds_Paths := Fold or else Hostkit.Host."=" (Hostkit.Host.Current, Hostkit.Host.Windows);
   end Simulate_Folding_Host;

end Files.Settings.Path_References.Testing;
