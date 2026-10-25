separate (Files_Suite.Interaction)
   procedure Test_Tree_Expand_Collapse_And_Hidden (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Ada.Strings.Unbounded;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Tree_Dir : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "tree");
      Alpha    : constant String := Files_Suite.Support.Join (Tree_Dir, "alpha");
      Beta     : constant String := Files_Suite.Support.Join (Tree_Dir, "beta");
      Secret   : constant String := Files_Suite.Support.Join (Tree_Dir, ".secret");
      A1       : constant String := Files_Suite.Support.Join (Alpha, "a1");
      Seeds    : Files.Folder_Tree.Entry_Seed_Vectors.Vector;
      Ignored  : Files.Controller.Controller_Result;
      Rows     : Files.Folder_Tree.Visible_Row_Vectors.Vector;

      function Row_Named (Src : Files.Folder_Tree.Visible_Row_Vectors.Vector; Name : String) return Natural is
      begin
         for R of Src loop
            if To_String (R.Name) = Name then
               return R.Node_Index;
            end if;
         end loop;
         return 0;
      end Row_Named;
   begin
      Files_Suite.Support.Reset_Root;
      Ada.Directories.Create_Path (Beta);
      Ada.Directories.Create_Path (Secret);
      Ada.Directories.Create_Path (A1);
      Files_Suite.Support.Write_File (Files_Suite.Support.Join (Tree_Dir, "file.txt"));

      Seeds.Append
        (Files.Folder_Tree.Entry_Seed'
           (Path => To_Unbounded_String (Tree_Dir), Name => To_Unbounded_String ("tree")));
      Files.Model.Seed_Tree (Model, Seeds);
      Files.Model.Open_Tree_Panel (Model);

      Rows := Files.Model.Tree_Visible_Rows (Model);
      Files_Suite.Support.Assert_Equal (Natural (Rows.Length), 1, "an unexpanded tree shows only its root node");

      Ignored := Files.Controller.Handle_Tree_Click (Model, Settings, 1, Toggle => True);
      Rows := Files.Model.Tree_Visible_Rows (Model);
      Files_Suite.Support.Assert_Equal (Natural (Rows.Length), 3, "expanding the root reveals its two subdirectories");
      Files_Suite.Support.Assert_Equal (Rows.Element (1).Depth, 0, "the root sits at depth zero");
      Assert
        (Rows.Element (2).Depth = 1 and then Rows.Element (3).Depth = 1,
         "the loaded children sit at depth one");

      Ignored :=
        Files.Controller.Handle_Targeted_Scroll
          (Model, Files.Events.Scroll_Tree_Panel, 1);
      Assert
        (Ignored.Status = Files.Controller.Controller_Command_Executed
         and then Files.Model.Tree_Panel_Scroll_Rows (Model) = 1,
         "targeted folder-tree scrolling advances the first requested row");
      Ignored :=
        Files.Controller.Handle_Targeted_Scroll
          (Model, Files.Events.Scroll_Tree_Panel, -1);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Tree_Panel_Scroll_Rows (Model),
         0,
         "folder-tree scrolling saturates back at the first row");
      declare
         Before : constant Natural := Files.Model.Revision (Model);
      begin
         Ignored :=
           Files.Controller.Handle_Targeted_Scroll
             (Model, Files.Events.Scroll_Tree_Panel, -1);
         Assert
           (Ignored.Status = Files.Controller.Controller_Ignored
            and then Files.Model.Revision (Model) = Before,
            "ignored tree scrolling at the first row leaves the model unchanged");
      end;

      Files_Suite.Support.Assert_Equal

        (Row_Named (Rows, ".secret"),

         0,

         "hidden directories are excluded when Show_Hidden_Files is off");
      Files_Suite.Support.Assert_Equal (Row_Named (Rows, "file.txt"), 0, "regular files are excluded from the tree");

      declare
         Alpha_Index : constant Natural := Row_Named (Rows, "alpha");
      begin
         Assert (Alpha_Index /= 0, "the alpha subdirectory is present");
         Ignored := Files.Controller.Handle_Tree_Click (Model, Settings, Alpha_Index, Toggle => True);
      end;
      Rows := Files.Model.Tree_Visible_Rows (Model);
      declare
         Depth_Two : Boolean := False;
      begin
         for R of Rows loop
            if To_String (R.Name) = "a1" then
               Depth_Two := R.Depth = 2;
            end if;
         end loop;
         Assert (Depth_Two, "expanding alpha reveals its child at depth two");
      end;

      Files.Model.Set_Tree_Panel_Scroll_Rows (Model, 3);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Tree_Panel_Scroll_Rows (Model),
         3,
         "the expanded tree can scroll to its final visible row");
      Ignored := Files.Controller.Handle_Tree_Click (Model, Settings, 1, Toggle => True);
      Rows := Files.Model.Tree_Visible_Rows (Model);
      Files_Suite.Support.Assert_Equal (Natural (Rows.Length), 1, "collapsing the root hides all its descendants");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Tree_Panel_Scroll_Rows (Model),
         0,
         "collapsing a branch clamps its now-hidden tree scroll offset");

      Ignored := Files.Controller.Handle_Tree_Click (Model, Settings, 1, Toggle => True);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Tree_Panel_Scroll_Rows (Model),
         0,
         "re-expanding a branch does not resurrect its obsolete scroll offset");
      Ignored := Files.Controller.Handle_Tree_Click (Model, Settings, 1, Toggle => True);

      declare
         Hidden_On : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Model2    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
         Seeds2    : Files.Folder_Tree.Entry_Seed_Vectors.Vector;
         Rows2     : Files.Folder_Tree.Visible_Row_Vectors.Vector;
      begin
         Hidden_On.Show_Hidden_Files := True;
         Seeds2.Append
           (Files.Folder_Tree.Entry_Seed'
              (Path => To_Unbounded_String (Tree_Dir), Name => To_Unbounded_String ("tree")));
         Files.Model.Seed_Tree (Model2, Seeds2);
         Files.Model.Open_Tree_Panel (Model2);
         Ignored := Files.Controller.Handle_Tree_Click (Model2, Hidden_On, 1, Toggle => True);
         Rows2 := Files.Model.Tree_Visible_Rows (Model2);
         Assert (Row_Named (Rows2, ".secret") /= 0, "hidden directories appear when Show_Hidden_Files is on");
      end;
   end Test_Tree_Expand_Collapse_And_Hidden;
