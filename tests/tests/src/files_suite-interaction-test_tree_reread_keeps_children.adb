separate (Files_Suite.Interaction)
   --  Expanding a folder again re-reads it, and every re-read used to append
   --  a fresh node per child: a tree browsed for a while grew without bound
   --  and every expanded subfolder collapsed. A child still there keeps its
   --  node, its subtree and its expanded state, and takes its new place.
   procedure Test_Tree_Reread_Keeps_Children (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Ada.Strings.Unbounded;
      Tree : Files.Folder_Tree.Tree;

      function Seeds (Names : String) return Files.Folder_Tree.Entry_Seed_Vectors.Vector is
         Result : Files.Folder_Tree.Entry_Seed_Vectors.Vector;
      begin
         for Name of Names loop
            Result.Append
              (Files.Folder_Tree.Entry_Seed'
                 (Path => To_Unbounded_String ("/r/" & Name), Name => To_Unbounded_String ([Name])));
         end loop;
         return Result;
      end Seeds;

      function Rows return String is
         Result : Unbounded_String;
      begin
         for R of Files.Folder_Tree.Visible_Rows (Tree) loop
            Append (Result, R.Name & ";");
         end loop;
         return To_String (Result);
      end Rows;

      Root : Files.Folder_Tree.Entry_Seed_Vectors.Vector;
   begin
      Root.Append
        (Files.Folder_Tree.Entry_Seed'(Path => To_Unbounded_String ("/r"), Name => To_Unbounded_String ("r")));
      Files.Folder_Tree.Seed (Tree, Root);
      Files.Folder_Tree.Replace_Children (Tree, 1, Seeds ("ab"));
      Files.Folder_Tree.Set_Expanded (Tree, 1, True);
      Files.Folder_Tree.Replace_Children (Tree, 2, Seeds ("x"));
      Files.Folder_Tree.Set_Expanded (Tree, 2, True);
      Files_Suite.Support.Assert_Equal (Rows, "r;a;x;b;", "the first reads attach the children");

      for Round in 1 .. 20 loop
         Files.Folder_Tree.Replace_Children (Tree, 1, Seeds ("ab"));
      end loop;
      Files_Suite.Support.Assert_Equal
        (Files.Folder_Tree.Node_Count (Tree), 4, "re-reading the same folder adds no nodes");
      Files_Suite.Support.Assert_Equal (Rows, "r;a;x;b;", "and an expanded subfolder stays expanded");

      Files.Folder_Tree.Replace_Children (Tree, 1, Seeds ("bac"));
      Files_Suite.Support.Assert_Equal
        (Rows, "r;b;a;x;c;", "kept children take the new listing's order, a new one is added");
      Files_Suite.Support.Assert_Equal (Files.Folder_Tree.Node_Count (Tree), 5, "only the new child is a new node");

      Files.Folder_Tree.Replace_Children (Tree, 1, Seeds ("a"));
      Files_Suite.Support.Assert_Equal (Rows, "r;a;x;", "a child that is gone is no longer shown");

      --  x read while empty loses its expander; once its parent is read again
      --  it offers one, so a subfolder made since can be reached.
      Files.Folder_Tree.Replace_Children (Tree, 4, Seeds (""));
      Assert (not Files.Folder_Tree.Visible_Rows (Tree).Element (3).Has_Children, "an empty folder has no expander");
      Files.Folder_Tree.Replace_Children (Tree, 2, Seeds ("x"));
      Assert
        (Files.Folder_Tree.Visible_Rows (Tree).Element (3).Has_Children,
         "re-reading its parent gives a once-empty folder its expander back");

      --  At scale: a folder of 1,000 subfolders expanded 50 times.
      declare
         Big      : Files.Folder_Tree.Tree;
         Children : Files.Folder_Tree.Entry_Seed_Vectors.Vector;
      begin
         Files.Folder_Tree.Seed (Big, Root);
         for Index in 1 .. 1_000 loop
            Children.Append
              (Files.Folder_Tree.Entry_Seed'
                 (Path => To_Unbounded_String ("/r/" & Index'Image), Name => To_Unbounded_String (Index'Image)));
         end loop;
         for Round in 1 .. 50 loop
            Files.Folder_Tree.Replace_Children (Big, 1, Children);
         end loop;
         Files_Suite.Support.Assert_Equal
           (Files.Folder_Tree.Node_Count (Big), 1_001, "fifty re-reads of 1,000 subfolders keep 1,001 nodes");
      end;
   end Test_Tree_Reread_Keeps_Children;
