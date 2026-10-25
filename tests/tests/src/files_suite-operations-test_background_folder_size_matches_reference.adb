separate (Files_Suite.Operations)
   procedure Test_Background_Folder_Size_Matches_Reference
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Tree      : constant String := Join (Root, "tree");
      Deep      : constant String := Join (Join (Tree, "a"), "b");
      Reference : Files.File_System.Directory_Size_Result;
      Path      : Ada.Strings.Unbounded.Unbounded_String;
      Result    : Files.File_System.Directory_Size_Result;
      Available : Boolean := False;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Deep);
      Ada.Directories.Create_Path (Join (Tree, "c"));
      --  4 files totalling 21 bytes across 3 nested directories (a, a/b, c).
      Write_Binary_File (Join (Tree, "root.txt"), "12345");            --  5 bytes
      Write_Binary_File (Join (Join (Tree, "a"), "mid.bin"), "0123456789");  --  10 bytes
      Write_Binary_File (Join (Deep, "leaf.dat"), "z");               --  1 byte
      Write_Binary_File (Join (Join (Tree, "c"), "note.md"), "hello"); --  5 bytes

      Reference := Files.File_System.Directory_Size (Tree);

      Files.Folder_Size.Cancel;
      Files.Folder_Size.Request (Tree);
      for Attempt in Polling (Limit => Seconds (Scaled (Poll_Limit))) loop
         Files.Folder_Size.Step (Budget => 100_000);
         Files.Folder_Size.Take (Path, Result, Available);
         exit when Available or else not Files.Folder_Size.Is_Active;
      end loop;

      Assert (Available, "background scan produced a finished result");
      Files_Suite.Support.Assert_Equal
        (Ada.Strings.Unbounded.To_String (Path),
         Tree,
         "result path matches the requested root");
      Files_Suite.Support.Assert_Equal
        (Result.Available,
         Reference.Available,
         "background totals equal Directory_Size for the same tree: availability");
      Files_Suite.Support.Assert_Equal
        (Result.Total_Bytes,
         Reference.Total_Bytes,
         "background totals equal Directory_Size for the same tree: bytes");
      Files_Suite.Support.Assert_Equal
        (Result.File_Count,
         Reference.File_Count,
         "background totals equal Directory_Size for the same tree: files");
      Files_Suite.Support.Assert_Equal
        (Result.Item_Count,
         Reference.Item_Count,
         "background totals equal Directory_Size for the same tree: items");
      Files_Suite.Support.Assert_Equal
        (Result.Capped,
         Reference.Capped,
         "background totals equal Directory_Size for the same tree: capped");
      --  Independent check of the constructed tree: 4 files, 21 bytes,
      --  4 files + 3 directories = 7 visited items, within the guards.
      Assert (Reference.Available, "reference totals match the constructed tree: available");
      Files_Suite.Support.Assert_Equal (Reference.File_Count, 4, "reference totals match the constructed tree: files");
      Files_Suite.Support.Assert_Equal
        (Reference.Total_Bytes, 21, "reference totals match the constructed tree: bytes");
      Files_Suite.Support.Assert_Equal (Reference.Item_Count, 7, "reference totals match the constructed tree: items");
      Assert (not Reference.Capped, "reference totals match the constructed tree: not capped");
   end Test_Background_Folder_Size_Matches_Reference;
