with Ada.Real_Time;
with Ada.Text_IO;
separate (Files_Suite.Tree)
   --  A tree of 150,000 shown folders flattens: its working arrays are sized
   --  by the node count, and on a 1 MiB stack (Windows' main thread) they
   --  overflowed it. It flattens once a change, not once a read: a snapshot,
   --  a scroll clamp and an arrow key ask for its rows and their count.
   procedure Test_Large_Folder_Tree (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Ada.Real_Time.Time;
      Start    : Ada.Real_Time.Time;
      Rounds   : constant := 20;
      Revision : Natural;
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
      Files.Folder_Tree.Replace_Children (Tree, 1, Children);
      Start := Ada.Real_Time.Clock;
      Files.Folder_Tree.Set_Expanded (Tree, 1, True);
      Ada.Text_IO.Put_Line
        ("large-tree: flatten 150k shown folders (once a change; was once a read)"
         & Duration'Image (Ada.Real_Time.To_Duration (Ada.Real_Time.Clock - Start) * 1000.0) & " ms");
      Revision := Files.Folder_Tree.Structure_Revision (Tree);
      Start := Ada.Real_Time.Clock;
      for Round in 1 .. Rounds loop
         Files_Suite.Support.Assert_Equal
           (Files.Folder_Tree.Visible_Row_Count (Tree), Children_Count + 1, "the count is kept");
      end loop;
      Ada.Text_IO.Put_Line
        ("large-tree: row count read"
         & Duration'Image (Ada.Real_Time.To_Duration (Ada.Real_Time.Clock - Start) * 1000.0 / Rounds) & " ms");
      Files_Suite.Support.Assert_Equal
        (Files.Folder_Tree.Structure_Revision (Tree), Revision, "reading moves no revision");
      Files.Folder_Tree.Set_Loading (Tree, 1, True);
      Assert (Files.Folder_Tree.Structure_Revision (Tree) /= Revision, "a change moves the revision");
      Assert (Files.Folder_Tree.Visible_Rows (Tree).First_Element.Loading, "the loading node shows it");
      Files.Folder_Tree.Replace_Children (Tree, 1, Children);
      Assert (not Files.Folder_Tree.Visible_Rows (Tree).First_Element.Loading, "its children end the loading");
      Files_Suite.Support.Assert_Equal
        (Natural (Files.Folder_Tree.Visible_Rows (Tree).Length),
         Children_Count + 1,
         "every shown folder is a row");
      Files_Suite.Support.Assert_Equal
        (Files.Folder_Tree.Visible_Row_Count (Tree),
         Children_Count + 1,
         "and is counted");
   end Test_Large_Folder_Tree;
