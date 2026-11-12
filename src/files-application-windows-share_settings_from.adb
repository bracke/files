separate (Files.Application.Windows)
   procedure Share_Settings_From
     (Runtime_Windows : in out Runtime_Window_Vectors.Vector;
      Index           : Positive) is
   begin
      if Files.Model.Settings_Revision (Runtime_Windows (Index).Model)
        = Runtime_Windows (Index).Synced_Settings_Revision
      then
         return;
      end if;

      for Other in Runtime_Windows.First_Index .. Runtime_Windows.Last_Index loop
         if Other /= Index then
            Files.Interaction.Adopt_Shared_Settings
              (Model    => Runtime_Windows (Other).Model,
               Settings => Runtime_Windows (Other).Settings,
               Shared   => Runtime_Windows (Index).Settings);
            --  The view snapshot needs no invalidating: Snapshot_Slots
            --  rebuilds it when the settings it reads (Cached_Settings_Key)
            --  differ. The cached frame does not compare them.
            Runtime_Windows (Other).Frame_Cache_Valid := False;
         end if;
         Runtime_Windows (Other).Synced_Settings_Revision :=
           Files.Model.Settings_Revision (Runtime_Windows (Other).Model);
      end loop;
   end Share_Settings_From;
