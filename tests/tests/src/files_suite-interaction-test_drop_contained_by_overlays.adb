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
         Files.Model.Reset_Type_Ahead (Model);
         Files.Model.Type_Ahead_Input (Model, "A", Matched);
         Assert (Matched and then Files.Model.Type_Ahead_Buffer (Model) = "A",
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
           (Files.Model.Type_Ahead_Buffer (Model),
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
           (not Files.Model.Paste_Conflict_Is_Active (Model)
            and then not Files.Model.Paste_Execution_Is_Active (Model),
            Name & " cannot start a hidden paste operation");
      end Assert_Contained;
   begin
      Roots.Append
        (Ada.Strings.Unbounded.To_Unbounded_String (Files.Model.Current_Path (Model)));
      --  The path need not exist: the overlay guard must reject the drop before
      --  planning examines any source path.
      Sources.Append (Ada.Strings.Unbounded.To_Unbounded_String ("/tmp/files-overlay-drop-source"));

      Seed_Type_Ahead;
      Files.Model.Toggle_Settings_Pane (Model);
      Assert_Contained ("the settings pane");
      Files.Model.Toggle_Settings_Pane (Model);

      Seed_Type_Ahead;
      Files.Model.Open_Command_Palette (Model);
      Assert_Contained ("the command palette");
      Files.Model.Close_Command_Palette (Model);

      Seed_Type_Ahead;
      Files.Model.Open_Root_Selector (Model, Roots);
      Assert_Contained ("the root selector");
      Files.Model.Close_Root_Selector (Model);

      Seed_Type_Ahead;
      Files.Model.Toggle_Sort_Menu (Model);
      Assert_Contained ("the sort menu");
      Files.Model.Close_Sort_Menu (Model);

      Seed_Type_Ahead;
      Files.Model.Open_Context_Menu (Model, 10, 10, Files.Model.Context_Menu_Empty);
      Assert_Contained ("the context menu");
      Files.Model.Close_Context_Menu (Model);

      Seed_Type_Ahead;
      Files.Model.Open_Label_Picker (Model);
      Assert_Contained ("the label picker");
      Files.Model.Close_Label_Picker (Model);

      Files_Suite.Support.Select_Name (Model, "Alpha.txt");
      Seed_Type_Ahead;
      Files.Model.Toggle_Quick_Look (Model);
      Assert (Files.Model.Quick_Look_Is_Open (Model), "Quick Look opens for the drop-containment test");
      Assert_Contained ("Quick Look");
      Files.Model.Close_Quick_Look (Model);

      Seed_Type_Ahead;
      Files.Model.Begin_Tree_Pick
        (Model, Files.Model.Pick_Copy, Sources, Files.Model.Current_Path (Model));
      Assert_Contained ("the destination picker");
      Files.Model.Clear_Tree_Pick (Model);
   end Test_Drop_Contained_By_Overlays;
