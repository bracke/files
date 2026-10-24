separate (Files_Suite.Operations)
   procedure Test_Directory_Size_Over_Links (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Tree    : constant String := Join (Root, "sized");
      Nested  : constant String := Join (Tree, "nested");
      Outside : constant String := Join (Root, "outside");
      Size    : Files.File_System.Directory_Size_Result;
      Linked  : Boolean;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Nested);
      Ada.Directories.Create_Path (Outside);
      Write_Binary_File (Join (Tree, "a.txt"), "12345");
      Write_Binary_File (Join (Nested, "c.txt"), "90");
      Write_Binary_File (Join (Outside, "big.bin"), [1 .. 4096 => 'x']);

      --  A link back to the root of the walk, a dangling link, and links to a
      --  file and a folder outside it. If symlinks are unsupported on this
      --  host, there is nothing to measure.
      if not Files_Suite.Support.Create_Symlink (Tree, Join (Nested, "up")) then
         Files_Suite.Support.Skip
           ("Test_Directory_Size_Over_Links",
            "not Files_Suite.Support.Create_Symlink (Tree, Join (Nested, ""up""))");
         return;
      end if;
      Linked :=
        Files_Suite.Support.Create_Symlink (Join (Root, "missing"), Join (Tree, "gone"))
        and then Files_Suite.Support.Create_Symlink (Join (Outside, "big.bin"), Join (Tree, "big"))
        and then Files_Suite.Support.Create_Symlink (Outside, Join (Tree, "away"));

      Size := Files.File_System.Directory_Size (Tree);

      --  Capture first, then remove the trees while their targets exist. The
      --  dangling link is invisible to Ada.Directories, so unlink it directly.
      declare
         Removed : Boolean;
      begin
         GNAT.OS_Lib.Delete_File (Join (Tree, "gone"), Removed);
         Linked := Linked and then Removed;
      end;
      Project_Tools.Files.Delete_Tree (Tree);
      Project_Tools.Files.Delete_Tree (Outside);

      Assert (Linked, "create the dangling and outward links");
      Assert (Size.Available and then not Size.Capped,
              "a cycle neither fails the walk nor runs it into a cap");
      Assert (Size.Total_Bytes = 7 and then Size.File_Count = 2,
              "only the tree's own files are summed, not what its links point at");
      Assert (Size.Item_Count = 7, "every link is counted once as an item:" & Size.Item_Count'Image);
   end Test_Directory_Size_Over_Links;
