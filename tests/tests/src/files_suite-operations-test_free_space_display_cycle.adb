separate (Files_Suite.Operations)
   procedure Test_Free_Space_Display_Cycle (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Path     : constant String := Join (Root, "settings.conf");
      Result   : Files.Controller.Controller_Result;
   begin
      Reset_Root;
      Assert (not Settings.Show_Used_Space, "starts in free-space mode: used space off");
      Assert (not Settings.Show_Space_Bar, "starts in free-space mode: space bar off");
      Result := Files.Controller.Toggle_Free_Space_Display (Model, Settings, Path);
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status, Files.Operations.Operation_Success, "free -> used: the toggle is saved");
      Assert (Settings.Show_Used_Space, "free -> used: used space on");
      Assert (not Settings.Show_Space_Bar, "free -> used: space bar off");
      Result := Files.Controller.Toggle_Free_Space_Display (Model, Settings, Path);
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status, Files.Operations.Operation_Success, "used -> bar: the toggle is saved");
      Assert (Settings.Show_Space_Bar, "used -> bar");
      Result := Files.Controller.Toggle_Free_Space_Display (Model, Settings, Path);
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status, Files.Operations.Operation_Success, "bar -> free: the toggle is saved");
      Assert (not Settings.Show_Used_Space, "bar -> free: used space off");
      Assert (not Settings.Show_Space_Bar, "bar -> free: space bar off");
   end Test_Free_Space_Display_Cycle;
