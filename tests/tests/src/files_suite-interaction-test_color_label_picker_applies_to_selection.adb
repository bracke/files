separate (Files_Suite.Interaction)
   procedure Test_Color_Label_Picker_Applies_To_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Dir      : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "label-group");
      One      : constant String := Files_Suite.Support.Join (Dir, "one.txt");
      Two      : constant String := Files_Suite.Support.Join (Dir, "two.txt");
      Three    : constant String := Files_Suite.Support.Join (Dir, "three.txt");
      Model    : Files.Model.Window_Model;
      Open_Cmd : constant Files.Events.Input_Action :=
        (Kind    => Files.Events.Command_Input_Action,
         Command => Files.Commands.Set_Color_Label_Command,
         others  => <>);

      function Choose (Label : Files.Types.Color_Label) return Files.Events.Input_Action is
      begin
         return
           (Kind       => Files.Events.Label_Picker_Choice_Input_Action,
            Item_Index => Files.Types.Color_Label'Pos (Label),
            others     => <>);
      end Choose;
   begin
      Files_Suite.Support.Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Files_Suite.Support.Write_File (One, "a");
      Files_Suite.Support.Write_File (Two, "b");
      Files_Suite.Support.Write_File (Three, "c");

      --  Open the picker on a multi-selection via the command seam.
      Model := Loaded_Model (Dir);
      Files.Model.Select_All_Visible (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         3,
         "all three files are selected before labeling");
      Files.Interaction.Apply_Input_Action
        (Model, Settings, "", Open_Cmd, Base_Font, Guikit.Input.No_Modifiers, Result);
      Assert (Files.Model.Label_Picker_Is_Open (Model), "the set-label command opens the picker");

      --  Choosing a color labels every selected item and closes the picker.
      Files.Interaction.Apply_Input_Action
        (Model, Settings, "", Choose (Files.Types.Green), Base_Font, Guikit.Input.No_Modifiers, Result);
      Assert (not Files.Model.Label_Picker_Is_Open (Model), "choosing a swatch closes the picker");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Label_Of (Settings, One),
         Files.Types.Green,
         "the first item is labeled green");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Label_Of (Settings, Two),
         Files.Types.Green,
         "the second item is labeled green");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Label_Of (Settings, Three),
         Files.Types.Green,
         "the third item is labeled green");
      Assert (Result.Settings_Changed, "labeling reports a settings change");

      --  A delayed choice from the closed picker is inert. In particular, it
      --  must not relabel the selection if another event was already queued.
      Files.Interaction.Apply_Input_Action
        (Model, Settings, "", Choose (Files.Types.Red), Base_Font,
         Guikit.Input.No_Modifiers, Result);
      Assert (not Files.Model.Label_Picker_Is_Open (Model),
              "a stale choice does not reopen the picker");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Label_Of (Settings, One),
         Files.Types.Green,
         "a stale choice does not relabel the selection");

      --  Public input actions carry a numeric payload. Reject a malformed
      --  value without raising or dismissing the active picker.
      Files.Model.Open_Label_Picker (Model);
      Files.Interaction.Apply_Input_Action
        (Model, Settings, "",
         (Kind       => Files.Events.Label_Picker_Choice_Input_Action,
          Item_Index => Files.Types.Color_Label'Pos (Files.Types.Color_Label'Last) + 1,
          others     => <>),
         Base_Font, Guikit.Input.No_Modifiers, Result);
      Assert (Files.Model.Label_Picker_Is_Open (Model),
              "an invalid choice leaves the picker available");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Label_Of (Settings, One),
         Files.Types.Green,
         "an invalid choice does not change labels");

      --  Choosing None clears every selected item's label.
      Files.Interaction.Apply_Input_Action
        (Model, Settings, "", Choose (Files.Types.No_Label), Base_Font, Guikit.Input.No_Modifiers, Result);
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Label_Of (Settings, One),
         Files.Types.No_Label,
         "None clears the first label");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Label_Of (Settings, Two),
         Files.Types.No_Label,
         "None clears the second label");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Label_Of (Settings, Three),
         Files.Types.No_Label,
         "None clears the third label");

      --  A mixed selection (one already labeled differently) all takes the
      --  chosen color.
      Files.Settings.Set_Label (Settings, Two, Files.Types.Red);
      Files.Model.Open_Label_Picker (Model);
      Files.Interaction.Apply_Input_Action
        (Model, Settings, "", Choose (Files.Types.Blue), Base_Font, Guikit.Input.No_Modifiers, Result);
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Label_Of (Settings, One),
         Files.Types.Blue,
         "the first item becomes blue");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Label_Of (Settings, Two),
         Files.Types.Blue,
         "the previously red item is overwritten to blue");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Label_Of (Settings, Three),
         Files.Types.Blue,
         "the third item becomes blue");
   end Test_Color_Label_Picker_Applies_To_Selection;
