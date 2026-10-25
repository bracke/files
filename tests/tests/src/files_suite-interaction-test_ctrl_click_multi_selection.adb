separate (Files_Suite.Interaction)
   procedure Test_Ctrl_Click_Multi_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      X1, Y1   : Natural;
      X2, Y2   : Natural;
      Found1   : Boolean;
      Found2   : Boolean;
   begin
      Item_Center (Model, 1, X1, Y1, Found1);
      Item_Center (Model, 3, X2, Y2, Found2);
      Assert (Found1 and then Found2, "layout cells exist for both target items");

      Click (Model, Settings, X1, Y1, Guikit.Input.No_Modifiers, Result);
      Files_Suite.Support.Assert_Equal (Selected_Item_Nodes (Model), 1, "a plain click starts a single-item selection");

      Click (Model, Settings, X2, Y2, Ctrl, Result);
      Assert
        (Files.Model.Is_Selected (Model, 1) and then Files.Model.Is_Selected (Model, 3),
         "ctrl-click adds the second item to the selection");
      Files_Suite.Support.Assert_Equal
        (Selected_Item_Nodes (Model),
         2,
         "two item nodes report Selected after ctrl-click");

      Click (Model, Settings, X1, Y1, Ctrl, Result);
      Assert (not Files.Model.Is_Selected (Model, 1), "ctrl-click toggles the first item back off");
      Assert (Files.Model.Is_Selected (Model, 3), "the other item stays selected");
      Files_Suite.Support.Assert_Equal
        (Selected_Item_Nodes (Model),
         1,
         "the toggled-off item is no longer reported Selected");
   end Test_Ctrl_Click_Multi_Selection;
