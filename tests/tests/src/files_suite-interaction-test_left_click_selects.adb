separate (Files_Suite.Interaction)
   procedure Test_Left_Click_Selects (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      X, Y     : Natural;
      Found    : Boolean;
   begin
      Item_Center (Model, 2, X, Y, Found);
      Assert (Found, "a layout cell exists for the target item");
      Click (Model, Settings, X, Y, Guikit.Input.No_Modifiers, Result);
      Assert (Files.Model.Is_Selected (Model, 2), "the clicked item becomes selected");
      Files_Suite.Support.Assert_Equal
        (Selected_Item_Nodes (Model),
         1,
         "exactly one item accessibility node reports Selected after a single click");
   end Test_Left_Click_Selects;
