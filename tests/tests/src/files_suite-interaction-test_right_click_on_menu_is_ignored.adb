separate (Files_Suite.Interaction)
   --  The context menu is drawn over the view. A right-click on it used to
   --  reach the item drawn beneath: the menu closed, the selection was
   --  cleared, and that hidden item became the only selection under a new
   --  menu. It is ignored now; the menu and the selection stay as they were.
   procedure Test_Right_Click_On_Menu_Is_Ignored (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      X, Y     : Natural;
      Found    : Boolean;
   begin
      Files.Model.Select_All_Visible (Model);
      Item_Center (Model, 1, X, Y, Found);
      Assert (Found, "a layout cell exists for the first item");
      Files.Interaction.Apply_Right_Click (Model, Settings, True, 1, X, Y, Result);
      Assert (Files.Model.Context_Menu_Is_Open (Model), "a right-click on a selected item opens the menu");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model), Files.Model.Visible_Count (Model), "and keeps the whole selection");

      Item_Center (Model, 2, X, Y, Found);
      Files.Model.Close_Context_Menu (Model);
      Files.Interaction.Apply_Right_Click (Model, Settings, True, 1, X, Y, Result);
      Files.Interaction.Apply_Right_Click (Model, Settings, True, 2, X + 1, Y + 1, Result, On_Context_Menu => True);
      Assert (Files.Model.Context_Menu_Is_Open (Model), "a right-click on the menu leaves it open");
      Files_Suite.Support.Assert_Equal (Files.Model.Context_Menu_X (Model), X, "where it was");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model), Files.Model.Visible_Count (Model),
         "and the item beneath does not take the selection");
   end Test_Right_Click_On_Menu_Is_Ignored;
