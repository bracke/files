with Files.Model.Tree_Panel;
separate (Files_Suite.Interaction)
   --  A folder expanded again shows what it holds now: a subfolder made and
   --  one removed since it was first expanded. Node indices stay stable: the
   --  root keeps its index, and an old child's index names no visible row.
   procedure Test_Tree_Reexpand_Rereads (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Ada.Strings.Unbounded;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Tree_Dir : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "tree");
      Seeds    : Files.Folder_Tree.Entry_Seed_Vectors.Vector;
      Ignored  : Files.Controller.Controller_Result;

      function Names return String is
         Result : Unbounded_String;
      begin
         for R of Files.Model.Tree_Panel.Visible_Rows (Model) loop
            Append (Result, R.Name & ";");
         end loop;
         return To_String (Result);
      end Names;
   begin
      Files_Suite.Support.Reset_Root;
      Ada.Directories.Create_Path (Files_Suite.Support.Join (Tree_Dir, "old"));
      Seeds.Append
        (Files.Folder_Tree.Entry_Seed'(Path => To_Unbounded_String (Tree_Dir), Name => To_Unbounded_String ("tree")));
      Files.Model.Tree_Panel.Seed (Model, Seeds);
      Files.Model.Tree_Panel.Open (Model);
      Assert (Files.Model.Tree_Panel.Roots_Match (Model, Seeds), "the tree's roots are the ones it was seeded with");

      Ignored := Files.Controller.Handle_Tree_Click (Model, Settings, 1, Toggle => True);
      Files_Suite.Support.Assert_Equal (Names, "tree;old;", "the first expand reads the folder");

      Ada.Directories.Delete_Directory (Files_Suite.Support.Join (Tree_Dir, "old"));
      Ada.Directories.Create_Path (Files_Suite.Support.Join (Tree_Dir, "new"));
      Ignored := Files.Controller.Handle_Tree_Click (Model, Settings, 1, Toggle => True);
      Files_Suite.Support.Assert_Equal (Names, "tree;", "collapsing hides the children");
      Ignored := Files.Controller.Handle_Tree_Click (Model, Settings, 1, Toggle => True);
      Files_Suite.Support.Assert_Equal (Names, "tree;new;", "expanding again shows the folder as it is now");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Tree_Panel.Visible_Rows (Model).Element (2).Node_Index, 3,
         "the new child takes a new index; the removed one's index is not reused");

      Seeds.Append
        (Files.Folder_Tree.Entry_Seed'
           (Path => To_Unbounded_String (Files_Suite.Support.Root), Name => To_Unbounded_String ("root")));
      Assert (not Files.Model.Tree_Panel.Roots_Match (Model, Seeds), "a changed set of roots does not match");
   end Test_Tree_Reexpand_Rereads;
