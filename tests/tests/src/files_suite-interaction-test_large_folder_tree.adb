separate (Files_Suite.Interaction)
   --  A tree of 150,000 shown folders flattens: its working arrays are sized
   --  by the node count, and on a 1 MiB stack (Windows' main thread) they
   --  overflowed it.
   procedure Test_Large_Folder_Tree (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Children_Count : constant := 150_000;
      Tree     : Files.Folder_Tree.Tree;
      Roots    : Files.Folder_Tree.Entry_Seed_Vectors.Vector;
      Children : Files.Folder_Tree.Entry_Seed_Vectors.Vector;
   begin
      Roots.Append
        (Files.Folder_Tree.Entry_Seed'
           (Path => Ada.Strings.Unbounded.To_Unbounded_String ("/root"),
            Name => Ada.Strings.Unbounded.To_Unbounded_String ("root")));
      Files.Folder_Tree.Seed (Tree, Roots);
      for Index in 1 .. Children_Count loop
         Children.Append
           (Files.Folder_Tree.Entry_Seed'
              (Path => Ada.Strings.Unbounded.To_Unbounded_String ("/root/" & Index'Image),
               Name => Ada.Strings.Unbounded.To_Unbounded_String (Index'Image)));
      end loop;
      Files.Folder_Tree.Set_Children (Tree, 1, Children);
      Files.Folder_Tree.Set_Expanded (Tree, 1, True);
      Files_Suite.Support.Assert_Equal
        (Natural (Files.Folder_Tree.Visible_Rows (Tree).Length),
         Children_Count + 1,
         "every shown folder is a row");
      Files_Suite.Support.Assert_Equal
        (Files.Folder_Tree.Visible_Row_Count (Tree),
         Children_Count + 1,
         "and is counted");
   end Test_Large_Folder_Tree;
