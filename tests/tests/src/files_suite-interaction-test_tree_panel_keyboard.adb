separate (Files_Suite.Interaction)
   procedure Test_Tree_Panel_Keyboard (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Ada.Strings.Unbounded;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      CResult  : Files.Controller.Controller_Result;
      Tree_Dir : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "panel-tree");
      Alpha    : constant String := Files_Suite.Support.Join (Tree_Dir, "alpha");
      Beta     : constant String := Files_Suite.Support.Join (Tree_Dir, "beta");
      A1       : constant String := Files_Suite.Support.Join (Alpha, "a1");
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Seeds    : Files.Folder_Tree.Entry_Seed_Vectors.Vector;
      Selected : Natural;

      procedure Tab (Backward : Boolean := False) is
      begin
         CResult :=
           Files.Controller.Handle_Key
             (Model, Settings, Guikit.Input.Key_Tab,
              (if Backward then [Guikit.Input.Shift_Key => True, others => False]
               else Guikit.Input.No_Modifiers));
      end Tab;
   begin
      Files_Suite.Support.Reset_Root;
      Ada.Directories.Create_Path (Beta);
      Ada.Directories.Create_Path (A1);
      Seeds.Append
        (Files.Folder_Tree.Entry_Seed'
           (Path => To_Unbounded_String (Tree_Dir), Name => To_Unbounded_String ("tree")));
      Files.Model.Seed_Tree (Model, Seeds);

      --  Closed, the tree is not part of the ring: filter -> grid as before.
      Tab;
      Tab;
      Tab;
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None
              and then not Files.Model.Tree_Has_Keyboard (Model),
              "with the tree closed, Tab from the filter returns to the grid");

      Files.Model.Open_Tree_Panel (Model);
      CResult := Files.Controller.Handle_Tree_Click (Model, Settings, 1, Toggle => True);

      --  Open, the filter hands on to the tree, and the tree back to the grid.
      Tab;
      Tab;
      Tab;
      Assert (Files.Model.Tree_Has_Keyboard (Model)
              and then Files.Model.Tree_Cursor (Model) /= "",
              "Tab from the filter gives the open tree the keyboard and a highlighted row");

      --  Arrows move the tree's highlight and leave the grid's selection alone.
      Selected := Files.Model.Selected_Index (Model);
      Files.Model.Set_Tree_Cursor (Model, Tree_Dir);
      CResult := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Down);
      Files_Suite.Support.Assert_Equal
        (CResult.Status, Files.Controller.Controller_Selection_Moved,
         "Down moves the tree highlight, not the grid selection (status)");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Tree_Cursor (Model), Alpha,
         "Down moves the tree highlight, not the grid selection (tree cursor)");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model), Selected,
         "Down moves the tree highlight, not the grid selection (grid selection)");
      CResult := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Right);
      Assert (CResult.Status = Files.Controller.Controller_Command_Executed
              and then Files.Model.Tree_Has_Keyboard (Model),
              "Right expands the highlighted folder and the tree keeps the keyboard");
      CResult := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Right);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Tree_Cursor (Model),
         A1,
         "Right on an expanded folder steps into it");
      CResult := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Left);
      Files_Suite.Support.Assert_Equal (Files.Model.Tree_Cursor (Model), Alpha, "Left steps out to the parent folder");

      --  Enter opens the highlighted folder in the main view.
      CResult := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Return);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Alpha,
         "Enter opens the highlighted folder in the main view");

      --  Escape gives the keyboard back to the grid; Shift+Tab from the grid
      --  comes back to the tree, and from the tree goes on to the filter.
      CResult := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Assert (not Files.Model.Tree_Has_Keyboard (Model), "Escape hands the keyboard back to the grid");
      Tab (Backward => True);
      Assert (Files.Model.Tree_Has_Keyboard (Model), "Shift+Tab from the grid reaches the open tree");
      Tab (Backward => True);
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_Filter_Input
              and then not Files.Model.Tree_Has_Keyboard (Model),
              "Shift+Tab from the tree goes on to the filter");

      --  Closing the panel ends its turn.
      Tab;
      Assert (Files.Model.Tree_Has_Keyboard (Model), "Tab from the filter returns to the tree");
      Files.Model.Close_Tree_Panel (Model);
      Assert (not Files.Model.Tree_Has_Keyboard (Model), "closing the tree takes its keyboard away");
   end Test_Tree_Panel_Keyboard;
