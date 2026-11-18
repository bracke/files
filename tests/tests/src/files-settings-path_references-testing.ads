--  Test seam of Files.Settings.Path_References: match stored paths as a
--  host whose volumes fold names (Windows) does, on any host.
package Files.Settings.Path_References.Testing is

   --  From now on (Fold => True) stored paths are matched without regard to
   --  case, as on Windows; Fold => False puts back this host's own rule.
   --
   --  @param Fold Whether to match as a folding host.
   procedure Simulate_Folding_Host (Fold : Boolean);

end Files.Settings.Path_References.Testing;
