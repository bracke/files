separate (Files_Suite.Operations)
   procedure Test_Item_Click_Selects_Without_Opening (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings  : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model     : Files.Model.Window_Model := Sample_Model;
      Routed    : Files.Controller.Controller_Result;
   begin
      Files.Model.Select_Visible (Model, 2);
      Files.Model.Focus_Filter_Input (Model);
      Routed := Files.Controller.Handle_Item_Click (Model, Settings, Visible_Index => 1);
      Files_Suite.Support.Assert_Equal
        (Routed.Status,
         Files.Controller.Controller_Selection_Moved,
         "click selects item without opening");
      Files_Suite.Support.Assert_Equal
        (Routed.Command,
         Files.Commands.No_Command,
         "selection click does not execute a command");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         1,
         "click selection updates selected visible index");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "item click clears text input focus");
      Routed := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Down);
      Files_Suite.Support.Assert_Equal
        (Routed.Status,
         Files.Controller.Controller_Selection_Moved,
         "arrow key moves after item click");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         2,
         "arrow key uses main view after item click");
      Files.Model.Focus_Path_Input (Model);
      Files.Controller.Replace_Focused_Text (Model, "/tmp/typed-path");
      Routed := Files.Controller.Handle_Item_Click (Model, Settings, Visible_Index => 0);
      Files_Suite.Support.Assert_Equal
        (Routed.Status,
         Files.Controller.Controller_Ignored,
         "outside item click is ignored");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         2,
         "outside item click preserves selection");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_Path_Input,
         "outside item click preserves focus");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Path_Input_Text (Model),
         "/tmp/typed-path",
         "outside item click preserves edited text");
   end Test_Item_Click_Selects_Without_Opening;
