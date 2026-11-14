with Files.Model.Label_Picker;
separate (Files_Suite.Interaction)
   procedure Test_Color_Label_Picker_Keyboard (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Dir      : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "label-kbd");
      One      : constant String := Files_Suite.Support.Join (Dir, "a.txt");
      Model    : Files.Model.Window_Model;
   begin
      Files_Suite.Support.Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Files_Suite.Support.Write_File (One, "a");
      Model := Loaded_Model (Dir);
      Files.Model.Selection.Select_All_Visible (Model);

      Files.Model.Label_Picker.Open (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Label_Picker.Highlight (Model),
         Files.Types.Clear_Swatch,
         "the picker opens on the clear swatch");

      --  Arrows move the highlight, clamped to the 1 .. Swatch_Count range.
      Files.Interaction.Handle_Key
        (Model, Settings, "", Guikit.Input.Key_Right, Guikit.Input.No_Modifiers, Result);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Label_Picker.Highlight (Model),
         Files.Types.Swatch_Count,
         "Right stays clamped at the last swatch");
      Files_Suite.Support.Assert_Equal (Natural (Files.Types.Swatch_Count), 8, "seven colors and the clear swatch");
      for Step in 1 .. 4 loop
         Files.Interaction.Handle_Key
           (Model, Settings, "", Guikit.Input.Key_Left, Guikit.Input.No_Modifiers, Result);
      end loop;
      Files_Suite.Support.Assert_Equal (Files.Model.Label_Picker.Highlight (Model), 4, "four Lefts land on swatch 4");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Label_Picker.Highlight_Color (Model),
         Files.Types.Green,
         "swatch 4 chooses Green");

      --  Enter applies the highlighted color to the whole selection and closes.
      Files.Interaction.Handle_Key
        (Model, Settings, "", Guikit.Input.Key_Return, Guikit.Input.No_Modifiers, Result);
      Assert (not Files.Model.Label_Picker.Is_Open (Model), "Enter closes the picker");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Label_Of (Settings, One),
         Files.Types.Green,
         "Enter applies the highlighted color to the selection");
   end Test_Color_Label_Picker_Keyboard;
