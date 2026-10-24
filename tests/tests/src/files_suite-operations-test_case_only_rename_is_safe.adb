separate (Files_Suite.Operations)
   procedure Test_Case_Only_Rename_Is_Safe (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Plain    : constant String := Join (Root, "plain.txt");
      Cased    : constant String := Join (Root, "Plain.txt");
      Lower    : constant String := Join (Root, "data.txt");
      Upper    : constant String := Join (Root, "DATA.txt");
      Other    : constant String := Join (Root, "other.txt");
      Link     : Files.File_System.Mutation_Result;
      Mutation : Files.File_System.Mutation_Result;
   begin
      Reset_Root;

      --  A case-changing rename with no existing destination takes the ordinary
      --  path and succeeds: the case flip works whenever nothing aliases it (the
      --  only case-only shape reproducible on a case-sensitive filesystem).
      Write_File (Plain, "hello");
      Mutation := Files.File_System.Rename_Item (Plain, Cased);
      Assert (Mutation.Success, "a case change with a free destination renames normally");
      if not Case_Insensitive_Filesystem then
         --  On a case-insensitive filesystem plain.txt and Plain.txt name the
         --  same entry, so the old-case name still resolves after the flip; the
         --  "source is gone" invariant only holds where case distinguishes names.
         Assert (not Ada.Directories.Exists (Plain), "the old-case source name no longer exists");
      end if;
      Assert (Ada.Directories.Exists (Cased), "the case-changed destination exists");

      --  The hazardous shape: data.txt and DATA.txt as two hard links to one
      --  inode reproduce the identity a case-insensitive filesystem reports for a
      --  case-only rename. On a case-sensitive host they are two independent
      --  directory entries, so the scratch-name second hop cannot land -- but the
      --  two-step must roll back cleanly and NEVER lose the file (the earlier
      --  naive fix dropped into Copy_Tree + delete here and destroyed the source).
      --  A case-insensitive filesystem cannot hold two such entries at once, and
      --  the free-destination flip above is already its native case-only rename,
      --  so this hand-built simulation only runs where case distinguishes names.
      if not Case_Insensitive_Filesystem then
         Write_File (Lower, "payload");
         Link := Files.File_System.Create_Hard_Link (Lower, Upper);
         Assert (Link.Success, "hard link creation succeeds on the test filesystem");

         Mutation := Files.File_System.Rename_Item (Lower, Upper);
         Assert (Ada.Directories.Exists (Lower), "the case-only rename leaves the source intact on rollback");
         Assert (Ada.Directories.Exists (Upper), "the case-only rename leaves the aliased name intact");
         Assert
           (Ada.Strings.Fixed.Index (Project_Tools.Files.Read_Raw_File (Lower), "payload") > 0,
            "no data is lost when the case-only rename rolls back");
         Assert
           (not Path_Exists (Lower & ".files-case-rename-0"),
            "the scratch rename name is not left behind");
      end if;

      --  A genuinely distinct existing destination is still refused as a collision.
      --  Ensure that destination exists first: on a case-insensitive filesystem
      --  the simulation above is skipped, so it did not leave data.txt behind.
      if not Ada.Directories.Exists (Lower) then
         Write_File (Lower, "payload");
      end if;
      Write_File (Other, "distinct");
      Mutation := Files.File_System.Rename_Item (Other, Lower);
      Assert (not Mutation.Success, "renaming onto a distinct existing file is still refused");
      Assert
        (To_String (Mutation.Error_Key) = "error.rename.invalid_destination",
         "the distinct-destination collision reports invalid destination");
      Assert (Ada.Directories.Exists (Other), "the refused collision leaves the source in place");

      --  Equal file identities do not make different directory entries a no-op.
      --  Both hard links and symbolic links can name the same file this way.
      for Symbolic in Boolean loop
         Reset_Root;
         declare
            Shared : constant String := Join (Root, "shared");
            Left_Directory : constant String := Join (Root, "left");
            Right_Directory : constant String := Join (Root, "right");
            Left_Name : constant String := Join (Left_Directory, "alias");
            Right_Name : constant String := Join (Right_Directory, "alias");
            Created_Left, Created_Right : Boolean;
         begin
            Ada.Directories.Create_Directory (Left_Directory);
            Ada.Directories.Create_Directory (Right_Directory);
            Write_File (Shared, "shared bytes");
            if Symbolic then
               Created_Left := Hostkit.Fs.Create_Link (Shared, Left_Name);
               Created_Right := Created_Left and then Hostkit.Fs.Create_Link (Shared, Right_Name);
            else
               Created_Left := Hostkit.Fs.Create_Hard_Link (Shared, Left_Name);
               Created_Right := Created_Left and then Hostkit.Fs.Create_Hard_Link (Shared, Right_Name);
            end if;
            if Created_Right then
               Mutation := Files.File_System.Rename_Item (Left_Name, Right_Name);
               Assert (not Mutation.Success
                       and then To_String (Mutation.Error_Key) = "error.rename.invalid_destination"
                       and then (if Symbolic then Hostkit.Fs.Is_Link (Left_Name)
                                 and then Hostkit.Fs.Is_Link (Right_Name)
                                 else Ada.Directories.Exists (Left_Name)
                                   and then Ada.Directories.Exists (Right_Name))
                       and then File_Has_Bytes (Shared, "shared bytes"),
                       "two entries with one target cannot be mistaken for a no-op rename");
            end if;
         end;
      end loop;

      Reset_Root;
      declare
         Source_Link : constant String := Join (Root, "link");
         Case_Link : constant String := Join (Root, "LINK");
      begin
         if Case_Insensitive_Filesystem then
            if Hostkit.Fs.Create_Link ("missing-target", Source_Link) then
               Mutation := Files.File_System.Rename_Item (Source_Link, Case_Link);
               Assert (Mutation.Success and then Hostkit.Fs.Is_Link (Case_Link),
                       "case-only rename moves a dangling link on a case-insensitive filesystem");
            end if;
         else
            Write_File (Join (Root, "shared"), "shared bytes");
            if Hostkit.Fs.Create_Link (Join (Root, "shared"), Source_Link)
              and then Hostkit.Fs.Create_Link (Join (Root, "shared"), Case_Link)
            then
               Mutation := Files.File_System.Rename_Item (Source_Link, Case_Link);
               Assert (not Mutation.Success
                       and then To_String (Mutation.Error_Key) = "error.rename.invalid_destination"
                       and then Hostkit.Fs.Is_Link (Source_Link)
                       and then Hostkit.Fs.Is_Link (Case_Link),
                       "different links to one target are a collision even when names differ only by case");
            end if;
         end if;
      end;
   end Test_Case_Only_Rename_Is_Safe;
