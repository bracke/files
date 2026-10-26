separate (Files_Suite.Commands)
   procedure Test_Escape_Dismisses_Grid_Popups (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Items    : Files.File_System.Item_Vectors.Vector;
      Model    : Files.Model.Window_Model;
      Result   : Files.Controller.Controller_Result;
      pragma Unreferenced (Result);
      Sources  : Files.Types.String_Vectors.Vector;
   begin
      Reset_Root;
      Items.Append (Files.File_System.Make_Item (Root, "a.txt", Files.Types.Regular_File_Item, "text/plain"));
      Items.Append (Files.File_System.Make_Item (Root, "b.txt", Files.Types.Regular_File_Item, "text/plain"));
      Files.Model.Initialize (Model, Root, Items, Root);

      --  Context menu: Escape closes it; and while it is open a non-Escape key is
      --  consumed rather than moving the grid hidden behind it.
      Files.Model.Open_Context_Menu (Model, 10, 10, Files.Types.Context_Menu_Empty);
      Assert (Files.Model.Context_Menu_Is_Open (Model), "context menu opens");
      declare
         Before : constant Natural := Files.Model.Selected_Index (Model);
      begin
         --  Down navigates the menu (see Test_Context_Menu_Keyboard); the point
         --  here is that it does not leak through to move the grid behind it.
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Down);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Selected_Index (Model),
            Before,
            "the grid does not move behind the context menu");
         Assert (Files.Model.Context_Menu_Is_Open (Model), "a non-Escape key leaves the menu open");
      end;
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Assert (not Files.Model.Context_Menu_Is_Open (Model), "Escape closes the context menu");

      --  Sort menu.
      Result := Files.Controller.Execute_Command (Files.Commands.Toggle_Sort_Menu_Command, Model, Settings);
      Assert (Files.Model.Sort_Menu_Is_Open (Model), "sort menu opens");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Assert (not Files.Model.Sort_Menu_Is_Open (Model), "Escape closes the sort menu");

      --  Color-label picker.
      Files.Model.Open_Label_Picker (Model);
      Assert (Files.Model.Label_Picker_Is_Open (Model), "label picker opens");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Assert (not Files.Model.Label_Picker_Is_Open (Model), "Escape closes the label picker");

      --  Modal destination-pick tree: Escape cancels the pick and closes the panel.
      Files.Model.Begin_Tree_Pick (Model, Files.Model.Pick_Move, Sources, "");
      Files.Model.Open_Tree_Panel (Model);
      Assert (Files.Model.Tree_Pick_Is_Active (Model), "tree pick is active");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Assert (not Files.Model.Tree_Pick_Is_Active (Model), "Escape cancels the tree pick");
      Assert (not Files.Model.Tree_Panel_Is_Open (Model), "Escape closes the pick tree panel");
   end Test_Escape_Dismisses_Grid_Popups;
