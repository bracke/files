separate (Files_Suite.Operations)
   procedure Test_Copy_Hard_Link_Trees (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : constant String := Join (Root, "source");
      Remote : Unbounded_String;
      Mutation : Files.File_System.Mutation_Result;
      Had_Tmp : constant Boolean := Ada.Environment_Variables.Exists ("TMPDIR");
      Old_Tmp : constant String := Ada.Environment_Variables.Value ("TMPDIR", "");
      procedure Restore_Tmp is
      begin
         if Had_Tmp then
            Ada.Environment_Variables.Set ("TMPDIR", Old_Tmp);
         else
            Ada.Environment_Variables.Clear ("TMPDIR");
         end if;
      end Restore_Tmp;
      procedure Cleanup is
      begin
         Restore_Tmp;
         if Length (Remote) > 0 then
            Project_Tools.Files.Delete_Tree (To_String (Remote));
         end if;
      end Cleanup;
      procedure Check (Path : String) is
      begin
         Assert (Files.File_Identities.Token (Join (Path, "first")) /= ""
                 and then Files.File_Identities.Token (Join (Path, "first"))
                   = Files.File_Identities.Token (Join (Path, "sub/second"))
                 and then Files.File_Identities.Token (Join (Path, "first"))
                   /= Files.File_Identities.Token (Join (Path, "unrelated")),
                 "preserve hard links across child directories without merging files with equal bytes");
         Write_Binary_File (Join (Path, "first"), "changed through one link");
         Assert (File_Has_Bytes (Join (Path, "sub/second"), "changed through one link")
                 and then File_Has_Bytes (Join (Path, "unrelated"), "linked bytes"),
                 "writes through a copied link update only its actual hard-linked sibling");
      end Check;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux then
         Files_Suite.Support.Skip ("Test_Copy_Hard_Link_Trees", "Hostkit.Host.Current /= Hostkit.Host.Linux");
         return;
      end if;
      Reset_Root;
      Ada.Directories.Create_Path (Join (Source, "sub"));
      Write_Binary_File (Join (Source, "first"), "linked bytes");
      Write_Binary_File (Join (Source, "unrelated"), "linked bytes");
      Assert (Hostkit.Fs.Create_Hard_Link (Join (Source, "first"), Join (Source, "sub/second")),
              "prepare a nested hard-link set");
      Mutation := Files.File_System.Copy_Tree (Source, Join (Root, "copy"));
      Assert (Mutation.Success, "copy the hard-link tree");
      Check (Join (Root, "copy"));
      Assert (File_Has_Bytes (Join (Source, "first"), "linked bytes"), "a copy's links are independent of the source");
      if not Ada.Directories.Exists ("/dev/shm") then
         Files_Suite.Support.Skip ("Test_Copy_Hard_Link_Trees", "not Ada.Directories.Exists (""/dev/shm"")");
         return;
      end if;
      Ada.Environment_Variables.Set ("TMPDIR", "/dev/shm");
      Remote := To_Unbounded_String (Hostkit.Fs.Create_Temporary_Directory ("files-test-hard-link-move-"));
      Restore_Tmp;
      if Length (Remote) = 0 then
         Files_Suite.Support.Skip ("Test_Copy_Hard_Link_Trees", "Length (Remote) = 0");
         return;
      end if;
      Mutation := Files.File_System.Rename_Item (Source, Join (To_String (Remote), "moved"));
      Assert (Mutation.Success and then not Ada.Directories.Exists (Source), "move the hard-link tree");
      Check (Join (To_String (Remote), "moved"));
      Mutation := Files.File_System.Rename_Item
        (Join (To_String (Remote), "moved"), Source,
         Files.File_Identities.Token (Join (To_String (Remote), "moved")));
      Assert (Mutation.Success, "a guarded history move preserves the hard-link topology");
      Check (Source);
      Cleanup;
   exception
      when others => Cleanup; raise;
   end Test_Copy_Hard_Link_Trees;
