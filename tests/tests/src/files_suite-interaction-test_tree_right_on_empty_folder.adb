separate (Files_Suite.Interaction)
   --  Right on an expanded folder steps into its first child; an expanded
   --  folder with no children keeps the highlight instead of handing it to
   --  the next sibling.
   procedure Test_Tree_Right_On_Empty_Folder (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Ada.Strings.Unbounded;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      CResult  : Files.Controller.Controller_Result;
      Tree_Dir : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "empty-tree");
      Alpha    : constant String := Files_Suite.Support.Join (Tree_Dir, "alpha");
      Beta     : constant String := Files_Suite.Support.Join (Tree_Dir, "beta");
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Seeds    : Files.Folder_Tree.Entry_Seed_Vectors.Vector;
   begin
      Files_Suite.Support.Reset_Root;
      Ada.Directories.Create_Path (Alpha);
      Ada.Directories.Create_Path (Beta);
      Seeds.Append
        (Files.Folder_Tree.Entry_Seed'
           (Path => To_Unbounded_String (Tree_Dir), Name => To_Unbounded_String ("tree")));
      Files.Model.Seed_Tree (Model, Seeds);
      Files.Model.Open_Tree_Panel (Model);
      CResult := Files.Controller.Handle_Tree_Click (Model, Settings, 1, Toggle => True);
      Files.Model.Give_Tree_Keyboard (Model);
      Files.Model.Set_Tree_Cursor (Model, Alpha);

      --  The first Right expands the empty folder (and finds nothing in it).
      CResult := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Right);
      Assert (CResult.Status = Files.Controller.Controller_Command_Executed
              and then Files.Model.Tree_Has_Keyboard (Model),
              "Right expands the folder and the tree keeps the keyboard");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Tree_Cursor (Model), Alpha, "expanding keeps the highlight on the folder");

      --  The second has no child to step into: nothing moves.
      CResult := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Right);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Tree_Cursor (Model), Alpha,
         "Right on an expanded folder with no children does not jump to the next sibling");

      --  Down still reaches the sibling.
      CResult := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Down);
      Files_Suite.Support.Assert_Equal (Files.Model.Tree_Cursor (Model), Beta, "Down moves on to the sibling");
      Files_Suite.Support.Reset_Root;
   end Test_Tree_Right_On_Empty_Folder;
