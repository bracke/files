separate (Files_Suite.Interaction)
   --  Home/End/PageUp/PageDown page the file-grid selection through the genuine
   --  key seam (Files.Interaction.Handle_Key) and never navigate: plain Home is
   --  distinct from Alt+Home (navigate home).
   procedure Test_Grid_Nav_Keys (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Home_Dir : constant String := Files.Model.Current_Path (Model);
      Last     : constant Positive := Files.Model.Visible_Count (Model);
      Result   : Files.Interaction.Interaction_Result;
   begin
      Files.Interaction.Handle_Key
        (Model             => Model,
         Settings          => Settings,
         Settings_Path     => "",
         Key               => Guikit.Input.Key_End,
         Current_Font_Size => Base_Font,
         Result            => Result);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Selection_Moved,
         "End moves the grid selection");
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Index (Model), Last, "End selects the last visible item");
      Files_Suite.Support.Assert_Equal (Files.Model.Current_Path (Model), Home_Dir, "End does not navigate");

      Files.Interaction.Handle_Key
        (Model             => Model,
         Settings          => Settings,
         Settings_Path     => "",
         Key               => Guikit.Input.Key_Home,
         Current_Font_Size => Base_Font,
         Result            => Result);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Selection_Moved,
         "Home moves the grid selection");
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Index (Model), 1, "Home selects the first visible item");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Home_Dir,
         "plain Home does not navigate home (that stays Alt+Home)");

      Files.Interaction.Handle_Key
        (Model             => Model,
         Settings          => Settings,
         Settings_Path     => "",
         Key               => Guikit.Input.Key_Page_Down,
         Current_Font_Size => Base_Font,
         Result            => Result);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         Last,
         "PageDown pages the selection down to the last item");

      Files.Interaction.Handle_Key
        (Model             => Model,
         Settings          => Settings,
         Settings_Path     => "",
         Key               => Guikit.Input.Key_Page_Up,
         Current_Font_Size => Base_Font,
         Result            => Result);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         1,
         "PageUp pages the selection back to the first item");
   end Test_Grid_Nav_Keys;
