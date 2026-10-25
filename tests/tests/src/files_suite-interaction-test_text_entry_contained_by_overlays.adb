separate (Files_Suite.Interaction)
   procedure Test_Text_Entry_Contained_By_Overlays
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Roots    : Files.Types.String_Vectors.Vector;
      Sources  : Files.Types.String_Vectors.Vector;

      procedure Prepare_Background is
      begin
         Files.Model.Set_Filter (Model, "");
         Files.Model.Reset_Type_Ahead (Model);
         Files_Suite.Support.Select_Name (Model, "Alpha.txt");
         --  A retained field focus makes this exercise hidden-field editing as
         --  well as the no-focus grid type-ahead path.
         Files.Model.Focus_Filter_Input (Model);
      end Prepare_Background;

      procedure Assert_Contained (Name : String) is
         Text_Outcome : constant Files.Controller.Controller_Result :=
           Files.Controller.Append_Focused_Text (Model, "G");
         Click_Outcome : Files.Controller.Controller_Result;
         Reduced       : Files.Interaction.Interaction_Result;
         Path_Before   : constant String := Files.Model.Current_Path (Model);
         Favorite_Before : constant Boolean :=
           Files.Settings.Is_Favorite (Settings, Path_Before);
         Scope_Before : constant Files.Types.Search_Scope :=
           Files.Model.Search_Scope_Of (Model);
      begin
         Files_Suite.Support.Assert_Equal
           (Text_Outcome.Status,
            Files.Controller.Controller_Ignored,
            Name & " ignores native character input");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Filter_Text (Model),
            "",
            Name & " leaves a hidden focused field unchanged");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Type_Ahead_Buffer (Model),
            "",
            Name & " leaves grid type-ahead unchanged");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Selected_Name (Model),
            "Alpha.txt",
            Name & " leaves the grid selection unchanged");

         Click_Outcome :=
           Files.Controller.Handle_Text_Click
             (Model, Files.Types.Focus_Filter_Input, 0);
         Assert
           (Click_Outcome.Status = Files.Controller.Controller_Ignored
            and then Files.Model.Filter_Text (Model) = "",
            Name & " rejects a delayed background text-field click");

         Click_Outcome :=
           Files.Controller.Handle_Item_Click
             (Model, Settings, Visible_Index => 2);
         Assert
           (Click_Outcome.Status = Files.Controller.Controller_Ignored
            and then Files.Model.Selected_Name (Model) = "Alpha.txt",
            Name & " rejects a delayed background item click");

         Click_Outcome :=
           Files.Controller.Handle_Breadcrumb_Click (Model, Settings, 1);
         Assert
           (Click_Outcome.Status = Files.Controller.Controller_Ignored
            and then Files.Model.Current_Path (Model) = Path_Before,
            Name & " rejects a delayed breadcrumb click");

         Files.Interaction.Apply_Input_Action
           (Model, Settings, "",
            (Kind => Files.Events.Path_Favorite_Toggle_Input_Action,
             others => <>),
            Base_Font, Guikit.Input.No_Modifiers, Reduced);
         Assert
           (Files.Settings.Is_Favorite (Settings, Path_Before) = Favorite_Before
            and then not Reduced.Settings_Changed,
            Name & " rejects a delayed path-star click");

         Files.Interaction.Apply_Input_Action
           (Model, Settings, "",
            (Kind => Files.Events.Search_Scope_Toggle_Input_Action,
             others => <>),
            Base_Font, Guikit.Input.No_Modifiers, Reduced);
         Assert
           (Files.Model.Search_Scope_Of (Model) = Scope_Before
            and then not Reduced.Directory_Reloaded,
            Name & " rejects a delayed search-scope click");
      end Assert_Contained;
   begin
      Roots.Append
        (Ada.Strings.Unbounded.To_Unbounded_String (Files.Model.Current_Path (Model)));
      Sources.Append (Ada.Strings.Unbounded.To_Unbounded_String ("/tmp/source"));

      Prepare_Background;
      Files.Model.Toggle_Settings_Pane (Model);
      Files.Model.Cancel_Focus_Or_Edit (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "the settings pane can remain open after focus is cancelled");
      Assert_Contained ("an unfocused settings pane");
      Files.Model.Toggle_Settings_Pane (Model);

      Prepare_Background;
      Files.Model.Open_Command_Palette (Model);
      Files.Model.Cancel_Focus_Or_Edit (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "the command palette can remain open after focus is cancelled");
      Assert_Contained ("an unfocused command palette");
      Files.Model.Close_Command_Palette (Model);

      Files.Model.Toggle_Settings_Pane (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_Settings_Input,
         "opening settings focuses its input surface");
      Files.Model.Open_Command_Palette (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_Command_Palette,
         "the command palette takes focus above settings");
      Files.Model.Close_Command_Palette (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_Settings_Input,
         "closing the command palette restores settings focus");
      Files.Model.Toggle_Settings_Pane (Model);

      Prepare_Background;
      Files.Model.Open_Root_Selector (Model, Roots);
      Assert_Contained ("the root selector");
      Files.Model.Close_Root_Selector (Model);

      Prepare_Background;
      Files.Model.Toggle_Sort_Menu (Model);
      Assert_Contained ("the sort menu");
      Files.Model.Close_Sort_Menu (Model);

      Prepare_Background;
      Files.Model.Open_Context_Menu (Model, 10, 10, Files.Model.Context_Menu_Empty);
      Assert_Contained ("the context menu");
      Files.Model.Close_Context_Menu (Model);

      Prepare_Background;
      Files.Model.Open_Label_Picker (Model);
      Assert_Contained ("the label picker");
      Files.Model.Close_Label_Picker (Model);

      Prepare_Background;
      Files.Model.Toggle_Quick_Look (Model);
      Assert (Files.Model.Quick_Look_Is_Open (Model), "Quick Look opens for the containment test");
      Assert_Contained ("Quick Look");
      Files.Model.Close_Quick_Look (Model);

      Prepare_Background;
      Files.Model.Begin_Tree_Pick
        (Model, Files.Model.Pick_Copy, Sources, Files.Model.Current_Path (Model));
      Assert_Contained ("the destination picker");
      Files.Model.Clear_Tree_Pick (Model);
   end Test_Text_Entry_Contained_By_Overlays;
