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
