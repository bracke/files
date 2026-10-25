separate (Files_Suite.Interaction)
   procedure Test_Shift_Click_Range_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      X1, Y1   : Natural;
      X3, Y3   : Natural;
      Found1   : Boolean;
      Found3   : Boolean;
   begin
      Item_Center (Model, 1, X1, Y1, Found1);
      Item_Center (Model, 3, X3, Y3, Found3);
      Assert (Found1 and then Found3, "layout cells exist for the range endpoints");

      Click (Model, Settings, X1, Y1, Guikit.Input.No_Modifiers, Result);
      Files_Suite.Support.Assert_Equal
        (Selected_Item_Nodes (Model),
         1,
         "a plain click anchors a single-item selection");

      Click (Model, Settings, X3, Y3, Shift, Result);
      Assert
        (Files.Model.Is_Selected (Model, 1),
         "shift-click selects the inclusive range from the anchor to the clicked item (item 1)");
      Assert
        (Files.Model.Is_Selected (Model, 2),
         "shift-click selects the inclusive range from the anchor to the clicked item (item 2)");
      Assert
        (Files.Model.Is_Selected (Model, 3),
         "shift-click selects the inclusive range from the anchor to the clicked item (item 3)");
      Files_Suite.Support.Assert_Equal
        (Selected_Item_Nodes (Model),
         3,
         "three item nodes report Selected after the shift-range click");
   end Test_Shift_Click_Range_Selection;
