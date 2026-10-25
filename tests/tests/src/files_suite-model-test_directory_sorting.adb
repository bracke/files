separate (Files_Suite.Model)
   procedure Test_Directory_Sorting (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dir      : constant String := Join (Root, "sort");
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Load     : Files.File_System.Directory_Load_Result;
      Case_Sensitive : Boolean;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Join (Dir, "zdir"));
      Write_File (Join (Dir, "b.txt"));
      Write_File (Join (Dir, "A.txt"));

      --  "A.txt" and "a.txt" are the same file on a case-insensitive filesystem,
      --  which macOS uses by default. The tie-break between names that differ
      --  only by case is exactly what the second half of this test pins down --
      --  and it cannot be staged where the two cannot coexist, so say so rather
      --  than assert against a fixture that was never built.
      Case_Sensitive := not Case_Insensitive_Filesystem;

      if Case_Sensitive then
         Write_File (Join (Dir, "a.txt"));
      end if;

      Write_File (Join (Root, "not-a-directory.txt"));
      Load := Files.File_System.Load_Directory (Dir, Settings);

      Assert (Load.Success, "directory load succeeds");
      Files_Suite.Support.Assert_Equal
        (Natural (Load.Items.Length),
         (if Case_Sensitive then 4 else 3),
         "all direct children are loaded; count=" & Natural'Image (Natural (Load.Items.Length)));
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (1).Name),
         "A.txt",
         "directory items sort by name with files");
      Load := Files.File_System.Load_Directory (Dir & "/.", Settings);
      Assert (Load.Success, "non-normal directory path loads");
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (1).Parent_Path),
         To_String (Load.Path),
         "item parent path is normalized");

      if Case_Sensitive then
         Files_Suite.Support.Assert_Equal
           (To_String (Load.Items.Element (2).Name),
            "a.txt",
            "case-insensitive equal names use deterministic fallback order");
         Files_Suite.Support.Assert_Equal
           (To_String (Load.Items.Element (3).Name),
            "b.txt",
            "fallback name order is deterministic");
         Files_Suite.Support.Assert_Equal
           (To_String (Load.Items.Element (4).Name),
            "zdir",
            "directories remain in normal name order");
      else
         Files_Suite.Support.Assert_Equal
           (To_String (Load.Items.Element (2).Name),
            "b.txt",
            "fallback name order is deterministic");
         Files_Suite.Support.Assert_Equal
           (To_String (Load.Items.Element (3).Name),
            "zdir",
            "directories remain in normal name order");
      end if;

      Load := Files.File_System.Load_Directory (Join (Root, "missing-directory"), Settings);
      Assert (not Load.Success, "missing directory load reports failure");
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Error_Key),
         "error.directory.load",
         "missing directory load reports error key");
      Load := Files.File_System.Load_Directory (Join (Root, "not-a-directory.txt"), Settings);
      Assert (not Load.Success, "file path directory load reports failure");
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Error_Key),
         "error.directory.load",
         "file path directory load reports error key");
   end Test_Directory_Sorting;
