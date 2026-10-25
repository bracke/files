separate (Files_Suite.Model)
   procedure Test_Root_Selector_Keyboard_Navigation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Target   : constant String := Join (Root, "selected-root");
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Roots_A  : Files.Types.String_Vectors.Vector;
      Result   : Files.Controller.Controller_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Target);
      Write_File (Join (Target, "inside.txt"));

      Files.Model.Initialize (Model, Root, Sample_Items, Root);
      Files.Model.Open_Root_Selector (Model, Files.Types.String_Vectors.Empty_Vector);
      Assert (not Files.Model.Root_Selector_Is_Open (Model), "empty root selector stays closed");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Root_Selected_Index (Model),
         0,
         "empty root selector has no selected row");
      Result := Files.Controller.Execute_Command (Files.Commands.Focus_Path_Input_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Command_Executed,
         "empty root selector does not create an invisible modal command blocker");
      Roots_A.Clear;
      Roots_A.Append (To_Unbounded_String (Root));
      Files.Model.Open_Root_Selector (Model, Roots_A);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Down);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "single root selector movement is ignored");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Home);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "root selector Home at first row is ignored");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_End);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "single root selector End is ignored");
      Roots_A.Clear;
      Roots_A.Append (To_Unbounded_String (Root));
      Roots_A.Append (To_Unbounded_String (Target));
      Roots_A.Append (To_Unbounded_String (Ada.Directories.Full_Name (Root)));
      Files.Model.Open_Root_Selector (Model, Roots_A);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Root_Selected_Index (Model),
         1,
         "non-empty root selector selects first row");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Down);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Selection_Moved,
         "Down moves root selector row");
      Files_Suite.Support.Assert_Equal (Files.Model.Root_Selected_Index (Model), 2, "Down selects next root row");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Up);
      Files_Suite.Support.Assert_Equal (Files.Model.Root_Selected_Index (Model), 1, "Up selects previous root row");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Up);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Root_Selected_Index (Model),
         3,
         "Up wraps root selector to last row");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Home);
      Files_Suite.Support.Assert_Equal (Files.Model.Root_Selected_Index (Model), 1, "Home selects first root row");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_End);
      Files_Suite.Support.Assert_Equal (Files.Model.Root_Selected_Index (Model), 3, "End selects last root row");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Right);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Selection_Moved,
         "Right wraps root selector to first row");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Root_Selected_Index (Model),
         1,
         "Right from last root row wraps to first row");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Left);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Selection_Moved,
         "Left wraps root selector to last row");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Root_Selected_Index (Model),
         3,
         "Left from first root row wraps to last row");
   end Test_Root_Selector_Keyboard_Navigation;
