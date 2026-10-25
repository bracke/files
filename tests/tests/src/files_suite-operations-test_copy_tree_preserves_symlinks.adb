separate (Files_Suite.Operations)
   procedure Test_Copy_Tree_Preserves_Symlinks (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Tree   : constant String := Join (Root, "src_tree");
      Nested : constant String := Join (Tree, "nested");
      Dest   : constant String := Join (Root, "dst_tree");
      Result : Files.File_System.Mutation_Result;

      Copied_Ok  : Boolean := False;
      File_Ok    : Boolean := False;
      Nested_Ok  : Boolean := False;
      Alias_Link : Boolean := False;
      Loop_Link  : Boolean := False;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Nested);
      Write_Binary_File (Join (Tree, "a.txt"), "12345");
      Write_Binary_File (Join (Nested, "c.txt"), "90");

      --  A self-referential link (points at an ancestor) plus a plain file link.
      --  Without symlinks there is nothing to assert; Link_Not_Made says so.
      if not Files_Suite.Support.Create_Symlink (Tree, Join (Tree, "loop")) then
         Files_Suite.Support.Link_Not_Made ("Test_Copy_Tree_Preserves_Symlinks");
         return;
      end if;
      declare
         Aliased_Link : constant Boolean :=
           Files_Suite.Support.Create_Symlink (Join (Tree, "a.txt"), Join (Tree, "alias"));
         pragma Unreferenced (Aliased_Link);
      begin
         null;
      end;

      Result := Files.File_System.Copy_Tree (Tree, Dest);

      --  Capture every outcome BEFORE cleanup, so an assertion failure cannot skip
      --  the cleanup and leave symlink-bearing fixtures that Reset_Root then trips
      --  over (a dangling link poisons every later test in the run).
      Copied_Ok  := Result.Success;
      File_Ok    := Files_Suite.Support.Path_Exists (Join (Dest, "a.txt"));
      Nested_Ok  := Files_Suite.Support.Path_Exists (Join (Join (Dest, "nested"), "c.txt"));
      Alias_Link := Hostkit.Fs.Is_Link (Join (Dest, "alias"));
      Loop_Link  := Hostkit.Fs.Is_Link (Join (Dest, "loop"));

      --  Fully remove both trees while their link targets still exist (so no link
      --  is left dangling for the delete), leaving nothing behind.
      Project_Tools.Files.Delete_Tree (Dest);
      Project_Tools.Files.Delete_Tree (Tree);

      Assert (Copied_Ok, "Copy_Tree completes despite a symlink cycle (no explosion)");
      Assert (File_Ok, "Copy_Tree copies regular files");
      Assert (Nested_Ok, "Copy_Tree recurses into real subdirectories");
      Assert
        (Alias_Link,
         "Copy_Tree reproduces a file symlink as a link, not a copy of its target");
      Assert
        (Loop_Link,
         "Copy_Tree reproduces the ancestor-cycle symlink as a link, not following it");
   end Test_Copy_Tree_Preserves_Symlinks;
