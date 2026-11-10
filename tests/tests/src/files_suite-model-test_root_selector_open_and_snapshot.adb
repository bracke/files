separate (Files_Suite.Model)
   procedure Test_Root_Selector_Open_And_Snapshot (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Entries  : Files.File_System.Root_Entry_Vectors.Vector;
      Result   : Files.Controller.Controller_Result;
      Snapshot : Files.Rendering.View_Snapshot;

      function Mount_With_Detail (Name : String) return String is
        (Files.Localization.Text
           ("root.detail",
            Files.Localization.Argument_List'
              [(To_Unbounded_String ("label"),
                To_Unbounded_String (Files.Localization.Text ("root.mount", "name", Name))),
               (To_Unbounded_String ("detail"), To_Unbounded_String ("ext4"))]));
   begin
      Files.Model.Set_Error (Model, "error.path.missing");
      Result := Files.Controller.Execute_Non_Settings_Command (Files.Commands.Select_Drive_Command, Model, Settings);
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
            Label => To_Unbounded_String ("root.mount"),
            Name  => To_Unbounded_String ("example-mount"),
            Detail => Null_Unbounded_String,
            Kind  => Files.File_System.Root_Mount,
            Volume_Name => To_Unbounded_String ("example-mount"),
            Ready => Files.File_System.Root_Ready,
            Removable => True));
      Files.Model.Open_Root_Selector (Model, Entries);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Assert
        (To_String (Snapshot.Root_Labels.Element (1)) =
         Files.Localization.Text ("root.mount", "name", "example-mount"),
         "root selector renders the root kind's localized pattern");
      Entries.Clear;
      Entries.Append
        (Files.File_System.Root_Entry'
           (Path  => To_Unbounded_String ("/tmp/example-mount"),
            Label => To_Unbounded_String ("root.mount"),
            Name  => To_Unbounded_String ("example-mount"),
            Detail => To_Unbounded_String ("ext4"),
            Kind  => Files.File_System.Root_Mount,
            Volume_Name => To_Unbounded_String ("example-mount"),
            Ready => Files.File_System.Root_Ready,
            Removable => True));
      Files.Model.Open_Root_Selector (Model, Entries);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Assert
        (To_String (Snapshot.Root_Labels.Element (1)) = Mount_With_Detail ("example-mount"),
         "root selector renders localized platform detail suffix");

      --  A name may hold any character a file name can, '|' too: it was a
      --  token separator, and "a|b" with a detail showed as "a" with "b|ext4".
      Entries.Clear;
      Entries.Append
        (Files.File_System.Root_Entry'
           (Path  => To_Unbounded_String ("/tmp/a|b"),
            Label => To_Unbounded_String ("root.mount"),
            Name  => To_Unbounded_String ("a|b"),
            Detail => To_Unbounded_String ("ext4"),
            Kind  => Files.File_System.Root_Mount,
            Volume_Name => To_Unbounded_String ("a|b"),
            Ready => Files.File_System.Root_Ready,
            Removable => True));
      Files.Model.Open_Root_Selector (Model, Entries);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Files_Suite.Support.Assert_Equal
        (To_String (Snapshot.Root_Labels.Element (1)), Mount_With_Detail ("a|b"),
         "a mount whose name holds '|' keeps its whole name and its detail");
   end Test_Root_Selector_Open_And_Snapshot;
