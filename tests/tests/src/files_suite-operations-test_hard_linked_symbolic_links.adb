separate (Files_Suite.Operations)
   procedure Test_Hard_Linked_Symbolic_Links (T : in out AUnit.Test_Cases.Test_Case'Class) is
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
         First : constant String := Join (Path, "first");
         Second : constant String := Join (Path, "sub/second");
         Target : Unbounded_String;
      begin
         Assert (Hostkit.Fs.Is_Link (First) and then Hostkit.Fs.Is_Link (Second)
                 and then Files.File_Identities.Token (First) /= ""
                 and then Files.File_Identities.Token (First) = Files.File_Identities.Token (Second),
                 "copied symbolic links retain their shared inode across child directories");
         Assert (Hostkit.Fs.Read_Link_Target (First, Target) and then To_String (Target) = "missing-target",
                 "hard-link preservation neither resolves nor alters a symbolic link target");
      end Check;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux or else not Ada.Directories.Exists ("/dev/shm") then
         Files_Suite.Support.Skip
           ("Test_Hard_Linked_Symbolic_Links",
            "Hostkit.Host.Current /= Hostkit.Host.Linux or else not Ada.Director...");
         return;
      end if;
      Reset_Root;
      Ada.Directories.Create_Path (Join (Source, "sub"));
      Assert (Hostkit.Fs.Create_Link ("missing-target", Join (Source, "first")), "create a dangling symbolic link");
      Assert (Hostkit.Fs.Create_Hard_Link (Join (Source, "first"), Join (Source, "sub/second")),
              "create a hard link to the symbolic link itself");
      Mutation := Files.File_System.Copy_Tree (Source, Join (Root, "copy"));
      Assert (Mutation.Success, "copy a tree containing hard-linked dangling symbolic links");
      Check (Join (Root, "copy"));
      Assert (Files.File_Identities.Token (Join (Root, "copy/first"))
              /= Files.File_Identities.Token (Join (Source, "first")), "the copied set is independent of its source");
      Ada.Environment_Variables.Set ("TMPDIR", "/dev/shm");
      Remote := To_Unbounded_String (Hostkit.Fs.Create_Temporary_Directory ("files-test-linked-symlinks-"));
      Restore_Tmp;
      if Length (Remote) = 0 then
         Files_Suite.Support.Skip ("Test_Hard_Linked_Symbolic_Links", "Length (Remote) = 0");
         return;
      end if;
      Mutation := Files.File_System.Rename_Item (Source, Join (To_String (Remote), "moved"));
      Assert (Mutation.Success and then not Ada.Directories.Exists (Source), "move the symbolic link set");
      Check (Join (To_String (Remote), "moved"));
      Mutation := Files.File_System.Rename_Item
        (Join (To_String (Remote), "moved"), Source,
         Files.File_Identities.Token (Join (To_String (Remote), "moved")));
      Assert (Mutation.Success, "restore the hard-linked symbolic link set through the guarded history path");
      Check (Source);
      Cleanup;
   exception
      when others =>
         Cleanup;
         raise;
   end Test_Hard_Linked_Symbolic_Links;
