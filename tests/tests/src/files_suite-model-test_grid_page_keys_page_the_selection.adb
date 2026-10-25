separate (Files_Suite.Model)
   procedure Test_Grid_Page_Keys_Page_The_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Result   : Files.Controller.Controller_Result;
   begin
      --  Over the file grid (info pane closed) plain Page Up / Page Down now
      --  page the SELECTION rather than scrolling the main view. The main view
      --  still scrolls through the wheel / targeted-scroll seam, which
      --  Test_Main_View_Scroll_And_Settings_Block covers.
      Files.Model.Select_Visible (Model, 1);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Page_Up);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "grid PageUp on the first item is ignored");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         1,
         "grid PageUp keeps the first item selected");

      declare
         Before : constant Natural := Files.Model.Revision (Model);
      begin
         Result := Files.Controller.Handle_Scroll (Model, Lines => -1);
         Files_Suite.Support.Assert_Equal
           (Result.Status,
            Files.Controller.Controller_Ignored,
            "negative main scroll at top is ignored");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Revision (Model),
            Before,
            "ignored main-view scrolling leaves the model revision unchanged");
      end;

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Page_Down);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Selection_Moved,
         "grid PageDown pages the selection");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         Files.Model.Visible_Count (Model),
         "grid PageDown moves the selection a full page down to the last item");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Page_Down);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "grid PageDown on the last item is ignored");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         Files.Model.Visible_Count (Model),
         "grid PageDown keeps the last item selected");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Page_Up);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Selection_Moved,
         "grid PageUp pages the selection back");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         1,
         "grid PageUp returns the selection to the first item");
   end Test_Grid_Page_Keys_Page_The_Selection;
