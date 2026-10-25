separate (Files_Suite.Model)
   procedure Test_Root_Selector_Settings_Exclusivity_And_Close (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Target   : constant String := Join (Root, "selected-root");
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Roots_A  : Files.Types.String_Vectors.Vector;
      Entries  : Files.File_System.Root_Entry_Vectors.Vector;
      Result   : Files.Controller.Controller_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Target);
      Write_File (Join (Target, "inside.txt"));
      Roots_A := Files.File_System.Available_Roots;
      --  Open the selected root and come back to Root, so the selector starts
      --  closed over a navigated window.
      Entries.Append
        (Files.File_System.Root_Entry'
           (Path  => To_Unbounded_String (Target),
            Label => To_Unbounded_String ("root.mount|selected-root"),
            Kind  => Files.File_System.Root_Mount,
            Volume_Name => To_Unbounded_String ("selected-root"),
            Ready => Files.File_System.Root_Ready,
            Removable => False));
      Files.Model.Open_Root_Selector (Model, Entries);
      Result := Files.Controller.Execute_Command (Files.Commands.Open_Selected_Root_Command, Model, Settings);
      Files.Model.Navigate_To (Model, Root, Files.File_System.Item_Vectors.Empty_Vector);
      Files.Model.Toggle_Settings_Pane (Model);
      Assert (Files.Model.Settings_Pane_Is_Open (Model), "settings pane opens before direct root selector call");
      Files.Model.Open_Root_Selector (Model, Entries);
      Assert (Files.Model.Root_Selector_Is_Open (Model), "direct root selector call opens root selector");
      Assert
        (not Files.Model.Settings_Pane_Is_Open (Model),
         "metadata root selector overload closes settings pane");
      Files.Model.Toggle_Settings_Pane (Model);
      Assert (Files.Model.Settings_Pane_Is_Open (Model), "settings pane reopens before string root selector call");
      Files.Model.Open_Root_Selector (Model, Roots_A);
      Assert (Files.Model.Root_Selector_Is_Open (Model), "string root selector overload opens root selector");
      Assert
        (not Files.Model.Settings_Pane_Is_Open (Model),
         "string root selector overload closes settings pane");

      Result := Files.Controller.Execute_Command (Files.Commands.Select_Drive_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Select_Drive_Command,
         "second drive selector click is routed");
      Assert (not Files.Model.Root_Selector_Is_Open (Model), "second drive selector click closes root selector");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Root,
         "second drive selector click does not navigate");

      Result := Files.Controller.Execute_Command (Files.Commands.Select_Drive_Command, Model, Settings);
      Assert (Files.Model.Root_Selector_Is_Open (Model), "drive selector reopens after toggle close");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Close_Command_Palette_Command,
         "Escape routes root selector close");
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Success,
         "root selector Escape reports successful state-only close");
      Assert (not Files.Model.Root_Selector_Is_Open (Model), "Escape closes root selector");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Root_Count (Model),
         0,
         "Escape clears closed root selector entries");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Root,
         "root selector Escape does not navigate");

      Result := Files.Controller.Execute_Command (Files.Commands.Select_Drive_Command, Model, Settings);
      Assert (Files.Model.Root_Selector_Is_Open (Model), "drive selector can reopen after Escape");
      Result := Files.Controller.Execute_Command (Files.Commands.Close_Command_Palette_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Close_Command_Palette_Command,
         "close command routes root selector close");
      Assert (not Files.Model.Root_Selector_Is_Open (Model), "close command closes root selector");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Root_Count (Model),
         0,
         "close command clears closed root selector entries");
      Result := Files.Controller.Execute_Command (Files.Commands.Select_Drive_Command, Model, Settings);
      Assert (Files.Model.Root_Selector_Is_Open (Model), "drive selector reopens after close command");
      Result := Files.Controller.Execute_Command (Files.Commands.Focus_Path_Input_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "root selector blocks path focus command");
      Assert (Files.Model.Root_Selector_Is_Open (Model), "blocked path focus keeps root selector open");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "blocked path focus leaves focus clear");
      Files.Model.Close_Root_Selector (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Root_Count (Model),
         0,
         "direct close clears closed root selector entries");
      Result := Files.Controller.Execute_Command (Files.Commands.Select_Drive_Command, Model, Settings);
      Assert (Files.Model.Root_Selector_Is_Open (Model), "drive selector reopens after blocked path focus");
      Result := Files.Controller.Execute_Command (Files.Commands.Open_Command_Palette_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Open_Command_Palette_Command,
         "palette command is routed");
      Assert (Files.Model.Command_Palette_Is_Open (Model), "palette opens from toolbar state");
      Assert (Files.Model.Root_Selector_Is_Open (Model), "palette opening preserves root selector");
      Result := Files.Controller.Handle_Text_Click (Model, Files.Types.Focus_Command_Palette, Cursor_Position => 0);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "same palette search cursor click is ignored");
      Assert (Files.Model.Root_Selector_Is_Open (Model), "palette search focus preserves root selector");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Assert (not Files.Model.Command_Palette_Is_Open (Model), "Escape closes palette after selector handoff");
      Assert (Files.Model.Root_Selector_Is_Open (Model), "Escape leaves root selector open after palette closes");
      Files.Model.Close_Root_Selector (Model);

      Result := Files.Controller.Execute_Command (Files.Commands.Open_Command_Palette_Command, Model, Settings);
      Files.Controller.Replace_Focused_Text (Model, "view.details");
      Result := Files.Controller.Execute_Command (Files.Commands.Select_Drive_Command, Model, Settings);
      Assert (Files.Model.Root_Selector_Is_Open (Model), "drive selector opens from palette state");
      Assert (not Files.Model.Command_Palette_Is_Open (Model), "drive selector closes command palette");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "drive selector clears palette focus");
      Files.Model.Close_Root_Selector (Model);
   end Test_Root_Selector_Settings_Exclusivity_And_Close;
