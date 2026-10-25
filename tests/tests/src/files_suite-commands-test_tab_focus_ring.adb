separate (Files_Suite.Commands)
   procedure Test_Tab_Focus_Ring (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Items    : Files.File_System.Item_Vectors.Vector;
      Model    : Files.Model.Window_Model;
      Result   : Files.Controller.Controller_Result;
      pragma Unreferenced (Result);
      Shift    : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
   begin
      Reset_Root;
      Items.Append (Files.File_System.Make_Item (Root, "a.txt", Files.Types.Regular_File_Item, "text/plain"));
      Files.Model.Initialize (Model, Root, Items, Root);
      Shift (Guikit.Input.Shift_Key) := True;

      --  Forward ring: grid -> path input -> filter -> grid.
      Files_Suite.Support.Assert_Equal (Files.Model.Focus (Model), Files.Types.Focus_None, "focus starts on the grid");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Tab);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_Path_Input,
         "Tab focuses the path input");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Tab);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_Filter_Input,
         "Tab focuses the filter input");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Tab);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "Tab returns focus to the grid");

      --  Backward ring: grid -> filter -> path -> grid.
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Tab, Shift);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_Filter_Input,
         "Shift+Tab focuses the filter input");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Tab, Shift);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_Path_Input,
         "Shift+Tab focuses the path input");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Tab, Shift);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "Shift+Tab returns focus to the grid");
   end Test_Tab_Focus_Ring;
