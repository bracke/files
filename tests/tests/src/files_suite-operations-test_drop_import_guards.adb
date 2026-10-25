separate (Files_Suite.Operations)
   procedure Test_Drop_Import_Guards (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Sources  : Files.Types.String_Vectors.Vector;
      Plans    : Files.File_System.Drop_Import_Result;
      Mutation : Files.File_System.Mutation_Result;
   begin
      Reset_Root;
      --  Moving an item into the directory it already lives in is a no-op, but
      --  copying into the same directory still makes a numbered duplicate.
      Sources.Clear;
      Write_File (Join (Root, "stay.txt"), "stay");
      Sources.Append (To_Unbounded_String (Join (Root, "stay.txt")));
      Plans := Files.File_System.Plan_Drop_Import (Sources, Root, Files.File_System.Drop_Move);
      Mutation := Files.File_System.Execute_Drop_Import (Plans.Plans);
      Assert (Mutation.Success, "same-directory move succeeds");
      Assert (Ada.Directories.Exists (Join (Root, "stay.txt")), "same-directory move keeps the file in place");
      Assert
        (not Ada.Directories.Exists (Join (Root, "stay 2.txt")),
         "same-directory move does not create a numbered duplicate");

      Sources.Clear;
      Sources.Append (To_Unbounded_String (Join (Root, "stay.txt")));
      Plans := Files.File_System.Plan_Drop_Import (Sources, Root, Files.File_System.Drop_Copy);
      Mutation := Files.File_System.Execute_Drop_Import (Plans.Plans);
      Assert (Mutation.Success, "same-directory copy succeeds");
      Assert
        (Ada.Directories.Exists (Join (Root, "stay 2.txt")),
         "same-directory copy still creates a numbered duplicate");

      --  A directory cannot be moved or copied into itself or a descendant;
      --  the recursive copy would otherwise recurse without bound.
      Ada.Directories.Create_Path (Join (Join (Root, "tree"), "sub"));
      Sources.Clear;
      Sources.Append (To_Unbounded_String (Join (Root, "tree")));
      Plans :=
        Files.File_System.Plan_Drop_Import
          (Sources, Join (Join (Root, "tree"), "sub"), Files.File_System.Drop_Move);
      Assert (not Plans.Success,
              "moving a directory into its own subtree is rejected; error was "
              & To_String (Plans.Error_Key));
      Files_Suite.Support.Assert_Equal
        (To_String (Plans.Error_Key),
         "error.drop.into_self",
         "into-self drop reports a deterministic diagnostic");
      Plans :=
        Files.File_System.Plan_Drop_Import
          (Sources, Join (Join (Root, "tree"), "sub"), Files.File_System.Drop_Copy);
      Assert (not Plans.Success, "copying a directory into its own subtree is rejected");
      Plans :=
        Files.File_System.Plan_Drop_Import
          (Sources, Join (Root, "tree"), Files.File_System.Drop_Copy);
      Assert (not Plans.Success, "copying a directory into itself is rejected");

      if Hostkit.Host.Current /= Hostkit.Host.Windows then
         --  A backslash is an ordinary filename byte on POSIX.  This sibling
         --  starts with the source name but is not inside the source tree.
         Ada.Directories.Create_Path (Join (Root, "tree\peer"));
         Plans :=
           Files.File_System.Plan_Drop_Import
             (Sources, Join (Root, "tree\peer"), Files.File_System.Drop_Copy);
         Assert
           (Plans.Success,
            "a POSIX backslash-name sibling is not mistaken for a descendant");
      end if;

      --  Two sources sharing a simple name from different directories must get
      --  distinct destinations within one batch (no silent overwrite).
      Ada.Directories.Create_Path (Join (Root, "src-a"));
      Ada.Directories.Create_Path (Join (Root, "src-b"));
      Write_File (Join (Join (Root, "src-a"), "dup.txt"), "a");
      Write_File (Join (Join (Root, "src-b"), "dup.txt"), "b");
      Ada.Directories.Create_Path (Join (Root, "dup-dest"));
      Sources.Clear;
      Sources.Append (To_Unbounded_String (Join (Join (Root, "src-a"), "dup.txt")));
      Sources.Append (To_Unbounded_String (Join (Join (Root, "src-b"), "dup.txt")));
      Plans :=
        Files.File_System.Plan_Drop_Import
          (Sources, Join (Root, "dup-dest"), Files.File_System.Drop_Copy);
      Assert (Plans.Success, "same-name batch drop plans successfully");
      Files_Suite.Support.Assert_Equal (Natural (Plans.Plans.Length), 2, "batch drop plans both sources");
      Assert
        (To_String (Plans.Plans.Element (1).Destination_Path)
           /= To_String (Plans.Plans.Element (2).Destination_Path),
         "same-name sources get distinct destinations within a batch");
      Mutation := Files.File_System.Execute_Drop_Import (Plans.Plans);
      Assert (Mutation.Success, "same-name batch copy executes");
      Assert
        (Ada.Directories.Exists (Join (Join (Root, "dup-dest"), "dup.txt")),
         "first same-name file is copied");
      Assert
        (Ada.Directories.Exists (Join (Join (Root, "dup-dest"), "dup 2.txt")),
         "second same-name file gets a distinct name instead of overwriting");
   end Test_Drop_Import_Guards;
