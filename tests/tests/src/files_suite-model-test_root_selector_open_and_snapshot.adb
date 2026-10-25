separate (Files_Suite.Model)
   procedure Test_Root_Selector_Open_And_Snapshot (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Entries  : Files.File_System.Root_Entry_Vectors.Vector;
      Result   : Files.Controller.Controller_Result;
      Snapshot : Files.Rendering.View_Snapshot;
   begin
      Files.Model.Set_Error (Model, "error.path.missing");
      Result := Files.Controller.Execute_Command (Files.Commands.Select_Drive_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Select_Drive_Command,
         "drive selector command is routed");
      Assert (Files.Model.Root_Selector_Is_Open (Model), "drive selector opens root selector");
      Assert (not Files.Model.Settings_Pane_Is_Open (Model), "root selector opening closes settings pane");
      Assert (Files.Model.Root_Count (Model) >= 1, "root selector contains at least one root");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Root_Selected_Index (Model),
         1,
         "root selector selects the first root by default");
      Assert (Files.Model.Root_Path (Model, 1) /= "", "root selector exposes a root path");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Root_Path (Model, 99),
         "",
         "invalid root selector index returns empty path");

      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Assert (Snapshot.Root_Selector_Open, "snapshot captures root selector visibility");
      Assert (not Snapshot.Settings_Pane_Open, "snapshot exposes root selector as exclusive settings modal");
      Files_Suite.Support.Assert_Equal
        (Snapshot.Root_Selected_Index,
         1,
         "snapshot captures selected root selector row");
      Files_Suite.Support.Assert_Equal
        (Natural (Snapshot.Root_Paths.Length),
         Files.Model.Root_Count (Model),
         "snapshot captures root selector paths");
      Files_Suite.Support.Assert_Equal
        (Natural (Snapshot.Root_Labels.Length),
         Files.Model.Root_Count (Model),
         "snapshot captures root selector labels");
      Assert (To_String (Snapshot.Root_Labels.Element (1)) /= "", "root selector label is non-empty");
      Entries.Clear;
      Entries.Append
        (Files.File_System.Root_Entry'
           (Path  => To_Unbounded_String ("/tmp/example-mount"),
            Label => To_Unbounded_String ("root.mount|example-mount"),
            Kind  => Files.File_System.Root_Mount,
            Volume_Name => To_Unbounded_String ("example-mount"),
            Ready => Files.File_System.Root_Ready,
            Removable => True));
      Files.Model.Open_Root_Selector (Model, Entries);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Assert
        (To_String (Snapshot.Root_Labels.Element (1)) =
         Files.Localization.Text ("root.mount.prefix") & "example-mount" &
         Files.Localization.Text ("root.mount.suffix"),
         "root selector renders localized root kind prefix");
      Entries.Clear;
      Entries.Append
        (Files.File_System.Root_Entry'
           (Path  => To_Unbounded_String ("/tmp/example-mount"),
            Label => To_Unbounded_String ("root.mount|example-mount|ext4"),
            Kind  => Files.File_System.Root_Mount,
            Volume_Name => To_Unbounded_String ("example-mount"),
            Ready => Files.File_System.Root_Ready,
            Removable => True));
      Files.Model.Open_Root_Selector (Model, Entries);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Assert
        (To_String (Snapshot.Root_Labels.Element (1)) =
         Files.Localization.Text ("root.mount.prefix") & "example-mount" &
         Files.Localization.Text ("root.detail.prefix") & "ext4" &
         Files.Localization.Text ("root.detail.suffix") &
         Files.Localization.Text ("root.mount.suffix"),
         "root selector renders localized platform detail suffix");
   end Test_Root_Selector_Open_And_Snapshot;
