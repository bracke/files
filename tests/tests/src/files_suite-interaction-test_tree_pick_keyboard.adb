separate (Files_Suite.Interaction)
   procedure Test_Tree_Pick_Keyboard (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Ada.Strings.Unbounded;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      CResult  : Files.Controller.Controller_Result;
      Tree_Dir : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "pick-tree");
      Alpha    : constant String := Files_Suite.Support.Join (Tree_Dir, "alpha");
      Beta     : constant String := Files_Suite.Support.Join (Tree_Dir, "beta");
      A1       : constant String := Files_Suite.Support.Join (Alpha, "a1");
      Src_File : constant String := Files_Suite.Support.Join (Tree_Dir, "src.txt");
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Seeds    : Files.Folder_Tree.Entry_Seed_Vectors.Vector;
      Sources  : Files.Types.String_Vectors.Vector;
      Rows     : Files.Folder_Tree.Visible_Row_Vectors.Vector;
   begin
      Files_Suite.Support.Reset_Root;
      Ada.Directories.Create_Path (Beta);
      Ada.Directories.Create_Path (A1);
      Files_Suite.Support.Write_File (Src_File, "x");

      Seeds.Append
        (Files.Folder_Tree.Entry_Seed'
           (Path => To_Unbounded_String (Tree_Dir), Name => To_Unbounded_String ("tree")));
      Files.Model.Seed_Tree (Model, Seeds);
      Files.Model.Open_Tree_Panel (Model);
      --  Expand the root so alpha and beta are visible rows.
      CResult := Files.Controller.Handle_Tree_Click (Model, Settings, 1, Toggle => True);
      Files_Suite.Support.Assert_Equal
        (CResult.Status,
         Files.Controller.Controller_Command_Executed,
         "expanding the destination tree reports an executed command");

      Sources.Append (To_Unbounded_String (Src_File));
      Files.Model.Begin_Tree_Pick (Model, Files.Model.Pick_Copy, Sources, "");
      Assert (Files.Model.Tree_Pick_Is_Active (Model), "the copy-to pick is active");

      --  The first Down lands on the first row; the next moves down one.
      Rows := Files.Model.Tree_Visible_Rows (Model);
      CResult := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Down);
      Assert
        (CResult.Status = Files.Controller.Controller_Selection_Moved
         and then Files.Model.Tree_Pick_Target (Model) = To_String (Rows.Element (1).Path),
         "the first arrow highlights the first tree row");
      CResult := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Down);
      Assert
        (CResult.Status = Files.Controller.Controller_Selection_Moved
         and then Files.Model.Tree_Pick_Target (Model) = To_String (Rows.Element (2).Path),
         "Down moves the highlight to the next row");
      CResult :=
        Files.Controller.Handle_Key
          (Model, Settings, Guikit.Input.Key_Down, Tree_Page_Rows => 2);
      Files_Suite.Support.Assert_Equal
        (CResult.Status, Files.Controller.Controller_Selection_Moved,
         "keyboard tree navigation reveals a highlight that crosses the viewport edge (status)");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Tree_Pick_Target (Model), To_String (Rows.Element (3).Path),
         "keyboard tree navigation reveals a highlight that crosses the viewport edge (target)");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Tree_Panel_Scroll_Rows (Model), 1,
         "keyboard tree navigation reveals a highlight that crosses the viewport edge (scroll rows)");

      --  Right on the alpha folder (which has a child) expands it; Left collapses.
      Files.Model.Set_Tree_Pick_Target (Model, Alpha);
      declare
         Before : constant Natural := Natural (Files.Model.Tree_Visible_Rows (Model).Length);
      begin
         CResult := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Right);
         Assert
           (CResult.Status = Files.Controller.Controller_Command_Executed
            and then Natural (Files.Model.Tree_Visible_Rows (Model).Length) > Before,
            "Right expands the highlighted folder");

         --  Select alpha's child, then collapse alpha through the independent
         --  disclosure-triangle path. The now-hidden child must not remain the
         --  destination that Choose would silently use.
         CResult := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Right);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Tree_Pick_Target (Model),
            A1,
            "Right on an expanded destination enters its first child");
         declare
            Expanded_Rows : constant Files.Folder_Tree.Visible_Row_Vectors.Vector :=
              Files.Model.Tree_Visible_Rows (Model);
            Alpha_Node : Natural := 0;
         begin
            for Row of Expanded_Rows loop
               if To_String (Row.Path) = Alpha then
                  Alpha_Node := Row.Node_Index;
               end if;
            end loop;
            Assert (Alpha_Node /= 0, "the expanded picker still exposes alpha");
            CResult :=
              Files.Controller.Handle_Tree_Click
                (Model, Settings, Alpha_Node, Toggle => True);
         end;
         Files_Suite.Support.Assert_Equal
           (CResult.Status, Files.Controller.Controller_Command_Executed,
            "collapsing an ancestor retargets a hidden destination to that ancestor (status)");
         Files_Suite.Support.Assert_Equal
           (Natural (Files.Model.Tree_Visible_Rows (Model).Length), Before,
            "collapsing an ancestor retargets a hidden destination to that ancestor (visible rows)");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Tree_Pick_Target (Model), Alpha,
            "collapsing an ancestor retargets a hidden destination to that ancestor (target)");
      end;

      --  Enter confirms the pick: copy the source into the highlighted folder
      --  (alpha). The sidebar was open before the pick, so it stays open.
      Files.Model.Set_Tree_Pick_Target (Model, Alpha);
      Files.Interaction.Handle_Key
        (Model, Settings, "", Guikit.Input.Key_Return, Guikit.Input.No_Modifiers, Base_Font, Result);
      Assert (not Files.Model.Tree_Pick_Is_Active (Model) and then Files.Model.Tree_Panel_Is_Open (Model),
              "Enter ends the pick and keeps the sidebar that was open before it");
      Assert
        (Ada.Directories.Exists (Files_Suite.Support.Join (Alpha, "src.txt")),
         "Enter copies the source into the highlighted destination");
   end Test_Tree_Pick_Keyboard;
