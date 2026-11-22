with Files.File_System.Testing;
with Files.File_System.Transfer;
with Files_Suite.Volumes;
separate (Files_Suite.Transfer)
   procedure Test_Copy_Hard_Link_Trees (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : constant String := Join (Root, "source");
      Remote : Files_Suite.Volumes.Remote_Directory;
      Mutation : Files.File_System.Mutation_Result;
      procedure Check (Path : String) is
      begin
         Assert (Files.File_Identities.Token (Join (Path, "first")) /= "",
                 "preserve hard links across child directories without merging files with equal bytes: identity");
         Files_Suite.Support.Assert_Equal
           (Files.File_Identities.Token (Join (Path, "first")),
            Files.File_Identities.Token (Join (Path, "sub/second")),
            "preserve hard links across child directories without merging files with equal bytes: linked");
         Assert (Files.File_Identities.Token (Join (Path, "first"))
                   /= Files.File_Identities.Token (Join (Path, "unrelated")),
                 "preserve hard links across child directories without merging files with equal bytes: not merged");
         Write_Binary_File (Join (Path, "first"), "changed through one link");
         Assert (File_Has_Bytes (Join (Path, "sub/second"), "changed through one link")
                 and then File_Has_Bytes (Join (Path, "unrelated"), "linked bytes"),
                 "writes through a copied link update only its actual hard-linked sibling");
      end Check;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Join (Source, "sub"));
      Write_Binary_File (Join (Source, "first"), "linked bytes");
      Write_Binary_File (Join (Source, "unrelated"), "linked bytes");
      Assert (Hostkit.Fs.Create_Hard_Link (Join (Source, "first"), Join (Source, "sub/second")),
              "prepare a nested hard-link set");
      Mutation := Files.File_System.Transfer.Copy_Tree (Source, Join (Root, "copy"));
      Assert (Mutation.Success, "copy the hard-link tree");
      Check (Join (Root, "copy"));
      Assert (File_Has_Bytes (Join (Source, "first"), "linked bytes"), "a copy's links are independent of the source");

      --  A destination that takes no hard links (FAT, exFAT, a network
      --  mount) still gets the whole tree: each name as a copy of its own.
      Files.File_System.Testing.Refuse_Hard_Links (True);
      Mutation := Files.File_System.Transfer.Copy_Tree (Source, Join (Root, "unlinked"));
      Files.File_System.Testing.Refuse_Hard_Links (False);
      Assert (Mutation.Success, "a refused hard link falls back to a copy: " & To_String (Mutation.Error_Key));
      Assert (File_Has_Bytes (Join (Root, "unlinked/first"), "linked bytes")
              and then File_Has_Bytes (Join (Root, "unlinked/sub/second"), "linked bytes"),
              "both names of a refused link hold the source's bytes");
      Assert (Files.File_Identities.Token (Join (Root, "unlinked/first"))
                /= Files.File_Identities.Token (Join (Root, "unlinked/sub/second")),
              "a refused link leaves two independent copies");
      --  Once the destination refused a link, further names of the inode
      --  are copied without reading the source and the first copy again:
      --  four names cost what two do.
      declare
         Two   : constant String := Join (Root, "two-names");
         Four  : constant String := Join (Root, "four-names");
         Reads : Natural;
         Two_Reads : Natural;
      begin
         Ada.Directories.Create_Path (Two);
         Ada.Directories.Create_Path (Four);
         Write_Binary_File (Join (Two, "a"), "linked bytes");
         Write_Binary_File (Join (Four, "a"), "linked bytes");
         Assert (Hostkit.Fs.Create_Hard_Link (Join (Two, "a"), Join (Two, "b"))
                 and then Hostkit.Fs.Create_Hard_Link (Join (Four, "a"), Join (Four, "b"))
                 and then Hostkit.Fs.Create_Hard_Link (Join (Four, "a"), Join (Four, "c"))
                 and then Hostkit.Fs.Create_Hard_Link (Join (Four, "a"), Join (Four, "d")),
                 "prepare two hard-link sets");
         Files.File_System.Testing.Refuse_Hard_Links (True);
         Reads := Files.File_System.Testing.Copy_Digest_Reads;
         Mutation := Files.File_System.Transfer.Copy_Tree (Two, Join (Root, "two-copied"));
         Assert (Mutation.Success, "copy two names where links are refused");
         Two_Reads := Files.File_System.Testing.Copy_Digest_Reads - Reads;
         Reads := Files.File_System.Testing.Copy_Digest_Reads;
         Mutation := Files.File_System.Transfer.Copy_Tree (Four, Join (Root, "four-copied"));
         Files.File_System.Testing.Refuse_Hard_Links (False);
         Assert (Mutation.Success, "copy four names where links are refused");
         Assert (Two_Reads > 0, "checking the first refused link reads the files");
         Files_Suite.Support.Assert_Equal
           (Files.File_System.Testing.Copy_Digest_Reads - Reads, Two_Reads,
            "names after a refused link are copied without reading the files again");
         for Name in Character range 'a' .. 'd' loop
            Assert (File_Has_Bytes (Join (Join (Root, "four-copied"), [Name]), "linked bytes"),
                    "every name of a refused link holds the source's bytes: " & Name);
         end loop;

         --  Two linked files, each with both names in a folder of its own
         --  (the walk lists a folder in no set order but copies it whole
         --  before the next): once the first file's link was refused, the
         --  second is copied as a plain file, its first name included, so
         --  the walk reads no more than it did for one linked file.
         declare
            Pairs : constant String := Join (Root, "two-files");
         begin
            Ada.Directories.Create_Path (Join (Pairs, "x"));
            Ada.Directories.Create_Path (Join (Pairs, "y"));
            Write_Binary_File (Join (Pairs, "x/x1"), "first file");
            Write_Binary_File (Join (Pairs, "y/y1"), "second file");
            Assert (Hostkit.Fs.Create_Hard_Link (Join (Pairs, "x/x1"), Join (Pairs, "x/x2"))
                    and then Hostkit.Fs.Create_Hard_Link (Join (Pairs, "y/y1"), Join (Pairs, "y/y2")),
                    "prepare two linked files");
            Files.File_System.Testing.Refuse_Hard_Links (True);
            Reads := Files.File_System.Testing.Copy_Digest_Reads;
            Mutation := Files.File_System.Transfer.Copy_Tree (Pairs, Join (Root, "two-files-copied"));
            Files.File_System.Testing.Refuse_Hard_Links (False);
            Assert (Mutation.Success, "copy two linked files where links are refused");
            Files_Suite.Support.Assert_Equal
              (Files.File_System.Testing.Copy_Digest_Reads - Reads, Two_Reads,
               "a second linked file after a refused link reads nothing to link it");
            Assert (File_Has_Bytes (Join (Root, "two-files-copied/x/x2"), "first file")
                    and then File_Has_Bytes (Join (Root, "two-files-copied/y/y1"), "second file")
                    and then File_Has_Bytes (Join (Root, "two-files-copied/y/y2"), "second file"),
                    "every name of both files holds its bytes");
         end;
      end;
      Remote.Create ("files-test-hard-link-move-");
      if Remote.Path = "" then
         Files_Suite.Support.Skip ("Test_Copy_Hard_Link_Trees", Files_Suite.Volumes.No_Other_Volume);
         return;
      end if;
      Mutation := Files.File_System.Rename_Item (Source, Join (Remote.Path, "moved"));
      Assert (Mutation.Success and then not Ada.Directories.Exists (Source), "move the hard-link tree");
      Check (Join (Remote.Path, "moved"));
      Mutation := Files.File_System.Rename_Item
        (Join (Remote.Path, "moved"), Source,
         Files.File_Identities.Token (Join (Remote.Path, "moved")));
      Assert (Mutation.Success, "a guarded history move preserves the hard-link topology");
      Check (Source);
   exception
      when others =>
         Files.File_System.Testing.Refuse_Hard_Links (False);
         raise;
   end Test_Copy_Hard_Link_Trees;
