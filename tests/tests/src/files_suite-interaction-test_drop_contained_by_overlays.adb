with Files.Model.Testing;
with Files.Model.Command_Palette;
with Files.Model.Context_Menu;
with Files.Model.Label_Picker;
with Files.Model.Quick_Look;
with Files.Model.Settings_Pane;
with Files.Model.Sort_Menu;
with Files.Model.Tree_Panel;
with Files.Model.Pasting;
separate (Files_Suite.Interaction)
   procedure Test_Drop_Contained_By_Overlays
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Roots    : Files.Types.String_Vectors.Vector;
      Sources  : Files.Types.String_Vectors.Vector;

      procedure Seed_Type_Ahead is
         Matched : Boolean;
      begin
         Files.Model.Selection.Reset_Type_Ahead (Model);
         Files.Model.Selection.Type_Ahead_Input (Model, "A", Matched);
         Assert (Matched and then Files.Model.Selection.Type_Ahead_Buffer (Model) = "A",
                 "prepare a live grid type-ahead prefix before opening an overlay");
      end Seed_Type_Ahead;

      procedure Assert_Contained (Name : String) is
         Revision : constant Natural := Files.Model.Revision (Model);
         Outcome  : constant Files.Controller.Controller_Result :=
           Files.Controller.Handle_Drop_Import (Model, Settings, Sources);
      begin
         Assert
           (Files.Model.Input_Owning_Overlay_Is_Open (Model),
            Name & " is covered by the shared input-overlay policy");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Selection.Type_Ahead_Buffer (Model),
            "",
            Name & " ends the previous grid type-ahead session when it opens");
         Files_Suite.Support.Assert_Equal
           (Outcome.Status,
            Files.Controller.Controller_Ignored,
            Name & " rejects a native file drop");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Revision (Model),
            Revision,
            Name & " leaves the model unchanged");
         Assert
           (not Files.Model.Pasting.Conflict_Is_Active (Model)
            and then not Files.Model.Pasting.Execution_Is_Active (Model),
            Name & " cannot start a hidden paste operation");
      end Assert_Contained;
   begin
      Roots.Append
        (Ada.Strings.Unbounded.To_Unbounded_String (Files.Model.Current_Path (Model)));
      --  The path need not exist: the overlay guard must reject the drop before
      --  planning examines any source path.
      Sources.Append (Ada.Strings.Unbounded.To_Unbounded_String ("/tmp/files-overlay-drop-source"));

      Seed_Type_Ahead;
      Files.Model.Settings_Pane.Toggle (Model);
      Assert_Contained ("the settings pane");
      Files.Model.Settings_Pane.Toggle (Model);

      Seed_Type_Ahead;
      Files.Model.Command_Palette.Open (Model);
      Assert_Contained ("the command palette");
      Files.Model.Command_Palette.Close (Model);

      Seed_Type_Ahead;
      Files.Model.Root_Selector.Open (Model, Roots);
      Assert_Contained ("the root selector");
      Files.Model.Root_Selector.Close (Model);

      Seed_Type_Ahead;
      Files.Model.Sort_Menu.Toggle (Model);
      Assert_Contained ("the sort menu");
      Files.Model.Sort_Menu.Close (Model);

      Seed_Type_Ahead;
      Files.Model.Context_Menu.Open (Model, 10, 10, Files.Types.Context_Menu_Empty);
      Assert_Contained ("the context menu");
      Files.Model.Context_Menu.Close (Model);

      Seed_Type_Ahead;
      Files.Model.Label_Picker.Open (Model);
      Assert_Contained ("the label picker");
      Files.Model.Label_Picker.Close (Model);

      Files_Suite.Support.Select_Name (Model, "Alpha.txt");
      Seed_Type_Ahead;
      Files.Model.Quick_Look.Toggle (Model);
      Assert (Files.Model.Quick_Look.Is_Open (Model), "Quick Look opens for the drop-containment test");
      Assert_Contained ("Quick Look");
      Files.Model.Quick_Look.Close (Model);

      Seed_Type_Ahead;
      Files.Model.Tree_Panel.Begin_Pick
        (Model, Files.Model.Pick_Copy, Sources, Files.Model.Current_Path (Model));
      Assert_Contained ("the destination picker");
      Files.Model.Testing.Clear_Tree_Pick (Model);
   end Test_Drop_Contained_By_Overlays;
