with Files.Input_Actions;
with Files.Settings_Form;
with Files.Model.Testing;
with Files.Model.Context_Menu;
with Files.Model.Label_Picker;
with Files.Model.Quick_Look;
with Files.Model.Settings_Pane;
with Files.Model.Tree_Panel;
with Files.Rendering.Layouts;
with Files_Suite.Support.Models;
separate (Files_Suite.Context_Menu)
   procedure Test_Right_Click_Opens_Menu (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Models.Sample_Model;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      X, Y     : Natural;
      Found    : Boolean;

      --  Right-click the centre of the item's cell through the real translator.
      procedure Right_Click (Target : Positive) is
      begin
         Item_Center (Model, Target, X, Y, Found);
         Right_Click_At (Model, Settings, X, Y, Result);
      end Right_Click;

      procedure Assert_Right_Click_Suppressed (Overlay_Name : String) is
      begin
         Right_Click (2);
         Assert
           (not Files.Model.Context_Menu.Is_Open (Model),
            "right-click behind " & Overlay_Name & " leaves the context menu closed");
      end Assert_Right_Click_Suppressed;
   begin
      Result.Settings_Changed := True;
      Result.Clear_Pending_Text := True;
      Right_Click (2);
      Assert (Found, "a layout cell exists for the right-clicked item");
      Assert (Files.Model.Context_Menu.Is_Open (Model), "right-click opens the context menu");
      Assert (Files.Model.Selection.Is_Selected (Model, 2), "right-click selects the unselected item under the cursor");
      Assert
        (not Result.Settings_Changed,
         "right-click clears follow-up flags left by an earlier interaction (settings changed)");
      Assert
        (not Result.Clear_Pending_Text,
         "right-click clears follow-up flags left by an earlier interaction (clear pending text)");

      --  With that menu still open, a right-click on another, unselected
      --  item the menu does not cover (the one before it: the menu opens
      --  rightwards from the click) moves the menu there and selects it alone.
      Right_Click (1);
      Assert (Files.Model.Context_Menu.Is_Open (Model), "a second right-click opens the menu again");
      Assert (Files.Model.Selection.Is_Selected (Model, 1), "it selects the newly right-clicked item");
      Assert (not Files.Model.Selection.Is_Selected (Model, 2), "and only that item");
      --  A right-click on the open menu itself is the menu's, so the item drawn
      --  under it is not taken; close the menu before right-clicking item 2.
      Files.Model.Context_Menu.Close (Model);
      Right_Click (2);

      --  A queued click can carry an index from an older layout. It must not
      --  open an item menu whose commands would act on the current selection.
      Dispatch_Right_Click
        (Model      => Model,
         Settings   => Settings,
         Target     => Files.Input_Actions.On_Main_View,
         Item_Index => Files.Model.Visible_Count (Model) + 1,
         X          => X,
         Y          => Y,
         Result     => Result);
      Assert
        (not Files.Model.Context_Menu.Is_Open (Model),
         "a stale right-click item index leaves the context menu closed");
      Assert
        (Files.Model.Selection.Is_Selected (Model, 2),
         "a stale right-click item index preserves the current selection");

      --  With a modal overlay open the same right-click must be swallowed: the
      --  menu stays closed (the shell suppresses it behind modals).
      Files.Model.Context_Menu.Close (Model);
      Files.Settings_Form.Begin_Edit (Model, Settings);
      Assert (Files.Model.Settings_Pane.Is_Open (Model), "settings overlay is open for the suppression case");
      Assert_Right_Click_Suppressed ("Settings");
      Files.Model.Settings_Pane.Close (Model);

      Files.Model.Label_Picker.Open (Model);
      Assert_Right_Click_Suppressed ("the label picker");
      Files.Model.Label_Picker.Close (Model);

      Files.Model.Quick_Look.Toggle (Model);
      Assert (Files.Model.Quick_Look.Is_Open (Model), "Quick Look opens for right-click suppression");
      Assert_Right_Click_Suppressed ("Quick Look");
      Files.Model.Quick_Look.Close (Model);

      declare
         Sources : Files.Types.String_Vectors.Vector;
      begin
         Sources.Append (Ada.Strings.Unbounded.To_Unbounded_String ("/tmp/source"));
         Files.Model.Tree_Panel.Begin_Pick (Model, Files.Model.Pick_Copy, Sources, "");
         Files.Model.Tree_Panel.Open (Model);
         Assert_Right_Click_Suppressed ("the destination picker");
         Files.Model.Testing.Clear_Tree_Pick (Model);
         Files.Model.Tree_Panel.Close (Model);
      end;
   end Test_Right_Click_Opens_Menu;
