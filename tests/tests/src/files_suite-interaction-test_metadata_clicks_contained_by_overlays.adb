with Files.Model.Info_Pane;
with Files.Input_Actions;
with Files.Model.Command_Palette;
with Files_Suite.Support.Models;
separate (Files_Suite.Interaction)
   procedure Test_Metadata_Clicks_Contained_By_Overlays
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Models.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Before   : Natural;
   begin
      Files.Model.Info_Pane.Toggle_Info_Pane (Model);
      Files.Model.Command_Palette.Open (Model);
      Before := Files.Model.Revision (Model);

      Files.Interaction.Apply_Input_Action
        (Model, Settings, "",
         (Kind       => Files.Input_Actions.Permission_Toggle_Input_Action,
          Bit        => 0),
         Guikit.Input.No_Modifiers, Result);
      Assert
        (Files.Model.Revision (Model) = Before
         and then Files.Model.Command_Palette.Is_Open (Model),
         "a stale permission click cannot mutate behind the command palette");

      Files.Interaction.Apply_Input_Action
        (Model, Settings, "",
         (Kind       => Files.Input_Actions.Ownership_Edit_Input_Action,
          Edit_Group => False),
         Guikit.Input.No_Modifiers, Result);
      Assert
        (Files.Model.Revision (Model) = Before
         and then Files.Model.Focus (Model) = Files.UI_Types.Focus_Command_Palette,
         "a stale ownership click cannot steal focus from the command palette");

      Files.Interaction.Apply_Input_Action
        (Model, Settings, "",
         (Kind    => Files.Input_Actions.Command_Input_Action,
          Command => Files.Commands.Toggle_Info_Pane_Command),
         Guikit.Input.No_Modifiers, Result);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Revision (Model), Before,
         "a stale background command cannot mutate behind the command palette (revision)");
      Assert
        (Files.Model.Info_Pane.Info_Pane_Is_Open (Model),
         "a stale background command cannot mutate behind the command palette (info pane open)");
      Assert
        (Files.Model.Command_Palette.Is_Open (Model),
         "a stale background command cannot mutate behind the command palette (palette open)");
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "a contained stale command reports no execution");
   end Test_Metadata_Clicks_Contained_By_Overlays;
