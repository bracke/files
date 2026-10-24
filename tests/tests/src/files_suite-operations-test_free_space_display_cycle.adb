separate (Files_Suite.Operations)
   procedure Test_Free_Space_Display_Cycle (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Path     : constant String := Join (Root, "settings.conf");
      Result   : Files.Controller.Controller_Result;
      pragma Unreferenced (Result);
   begin
      Reset_Root;
      Assert (not Settings.Show_Used_Space and then not Settings.Show_Space_Bar,
              "starts in free-space mode");
      Result := Files.Controller.Toggle_Free_Space_Display (Model, Settings, Path);
      Assert (Settings.Show_Used_Space and then not Settings.Show_Space_Bar,
              "free -> used");
      Result := Files.Controller.Toggle_Free_Space_Display (Model, Settings, Path);
      Assert (Settings.Show_Space_Bar, "used -> bar");
      Result := Files.Controller.Toggle_Free_Space_Display (Model, Settings, Path);
      Assert (not Settings.Show_Used_Space and then not Settings.Show_Space_Bar,
              "bar -> free");
   end Test_Free_Space_Display_Cycle;
