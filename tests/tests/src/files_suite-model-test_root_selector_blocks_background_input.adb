separate (Files_Suite.Model)
   procedure Test_Root_Selector_Blocks_Background_Input (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Target   : constant String := Join (Root, "selected-root");
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Roots_A  : Files.Types.String_Vectors.Vector;
      Result   : Files.Controller.Controller_Result;
      Snapshot : Files.Rendering.View_Snapshot;
      Ctrl     : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
   begin
      Ctrl (Guikit.Input.Control_Key) := True;
      Reset_Root;
      Ada.Directories.Create_Path (Target);
      Write_File (Join (Target, "inside.txt"));
      --  A three-row selector opened over a focused path input.
      Files.Model.Initialize (Model, Root, Sample_Items, Root);
      Result := Files.Controller.Execute_Command (Files.Commands.Focus_Path_Input_Command, Model, Settings);
      Roots_A.Append (To_Unbounded_String (Root));
      Roots_A.Append (To_Unbounded_String (Target));
      Roots_A.Append (To_Unbounded_String (Ada.Directories.Full_Name (Root)));
      Files.Model.Open_Root_Selector (Model, Roots_A);
      Files.Model.Select_Visible (Model, 1);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Delete);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "root selector blocks background delete key");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         1,
         "blocked root selector delete keeps selection");
      Assert (Files.Model.Root_Selector_Is_Open (Model), "blocked root selector delete keeps selector open");
      Result := Files.Controller.Handle_Text_Click (Model, Files.Types.Focus_Path_Input, Cursor_Position => 1);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "root selector blocks background text focus");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "blocked text focus leaves focus clear");
      Result := Files.Controller.Handle_Scroll (Model, Lines => 3);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "root selector blocks background wheel scroll");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Main_View_Scroll_Lines (Model),
         0,
         "blocked root selector scroll leaves main view still");
      Result :=
        Files.Controller.Handle_Targeted_Scroll
          (Model,
           Files.Events.Scroll_Auto,
           Lines => 3);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "root selector blocks targeted auto scroll");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Main_View_Scroll_Lines (Model),
         0,
         "blocked root auto scroll leaves main view still");
      Result :=
        Files.Controller.Handle_Targeted_Scroll
          (Model,
           Files.Events.Scroll_Main_View,
           Lines => 3);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "root selector blocks targeted main scroll");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_P, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Open_Command_Palette_Command,
         "root selector allows palette shortcut");
      Assert (Files.Model.Command_Palette_Is_Open (Model), "palette opens over root selector from shortcut");
      Assert (Files.Model.Root_Selector_Is_Open (Model), "palette shortcut keeps root selector available");
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Assert (Snapshot.Command_Palette_Open, "snapshot exposes the active palette overlay");
      Assert
        (not Snapshot.Root_Selector_Open,
         "snapshot suppresses root selector drawing while the palette is above it");
      Result := Files.Controller.Handle_Text_Click (Model, Files.Types.Focus_Command_Palette, Cursor_Position => 0);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "same palette search cursor click is ignored over root selector");
      Files.Model.Close_Command_Palette (Model);
      Result := Files.Controller.Execute_Command (Files.Commands.Focus_Path_Input_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "root selector blocks direct path focus command");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "blocked direct path focus leaves focus clear");
      Files.Model.Set_Error (Model, "error.path.missing");
      Result := Files.Controller.Execute_Command (Files.Commands.Delete_Selected_Items_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "root selector blocks direct delete command");
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Count (Model), 1, "blocked direct delete keeps selection");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.path.missing",
         "modal command block does not replace existing error");
      Result := Files.Controller.Execute_Command (Files.Commands.Toggle_Settings_Pane_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "root selector blocks direct settings command");
      Assert (Files.Model.Root_Selector_Is_Open (Model), "blocked direct settings keeps root selector open");
      Assert (not Files.Model.Settings_Pane_Is_Open (Model), "blocked direct settings leaves settings pane closed");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.path.missing",
         "root selector settings block preserves existing error");
      Result := Files.Controller.Execute_Command (Files.Commands.Open_Command_Palette_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Open_Command_Palette_Command,
         "root selector allows direct palette command");
      Assert (Files.Model.Command_Palette_Is_Open (Model), "direct palette command opens over root selector");
      Files.Model.Close_Command_Palette (Model);
      Result := Files.Controller.Execute_Command (Files.Commands.Select_Drive_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Select_Drive_Command,
         "root selector allows drive toggle command");
      Assert (not Files.Model.Root_Selector_Is_Open (Model), "drive toggle closes root selector");
   end Test_Root_Selector_Blocks_Background_Input;
