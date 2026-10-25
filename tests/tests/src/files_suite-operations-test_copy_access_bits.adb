separate (Files_Suite.Operations)
   procedure Test_Copy_Access_Bits (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Mutation : Files.File_System.Mutation_Result;
      Available : Boolean;
      Mode : Natural;
      Source : constant String := Join (Root, "source");
      Dest : constant String := Join (Root, "destination");
   begin
      if not Hostkit.Metadata.Mode_Bits_Are_Native then
         Files_Suite.Support.Skip ("Test_Copy_Access_Bits", "not Hostkit.Metadata.Mode_Bits_Are_Native");
         return;
      end if;
      for Directory_Copy in Boolean loop
         Reset_Root;
         if Directory_Copy then
            Ada.Directories.Create_Directory (Source);
            Write_Binary_File (Join (Source, "run.sh"), "executable bytes");
            Mutation := Files.File_System.Set_Permissions (Join (Source, "run.sh"), 8#750#);
            Assert (Mutation.Success, "prepare nested executable");
         else
            Write_Binary_File (Source, "executable bytes");
         end if;
         Mutation := Files.File_System.Set_Permissions (Source, 8#750#);
         Assert (Mutation.Success, "prepare source access bits");
         Mutation := Files.File_System.Copy_Tree (Source, Dest);
         Mode := Files.File_System.Permission_Bits_Of (Dest, Available);
         Assert (Mutation.Success, "copy preserves ordinary access bits on files and directories: copied");
         Assert (Available, "copy preserves ordinary access bits on files and directories: mode readable");
         Files_Suite.Support.Assert_Equal
           (Mode, 8#750#, "copy preserves ordinary access bits on files and directories: mode");
         if Directory_Copy then
            Mode := Files.File_System.Permission_Bits_Of (Join (Dest, "run.sh"), Available);
            Assert (Available, "recursive copies preserve executable bits and content: mode readable");
            Files_Suite.Support.Assert_Equal
              (Mode, 8#750#, "recursive copies preserve executable bits and content: mode");
            Assert (File_Has_Bytes (Join (Dest, "run.sh"), "executable bytes"),
                    "recursive copies preserve executable bits and content: content");
         end if;
      end loop;
      Reset_Root;
      Ada.Directories.Create_Directory (Source);
      Mutation := Files.File_System.Set_Permissions (Source, 8#7777#);
      Assert (Mutation.Success, "prepare sticky and privilege bits");
      Mutation := Files.File_System.Copy_Tree (Source, Dest);
      Mode := Files.File_System.Permission_Bits_Of (Dest, Available);
      Assert (Mutation.Success,
              "directory copies preserve sticky deletion protection while stripping setuid and setgid: copied");
      Assert (Available,
              "directory copies preserve sticky deletion protection while stripping setuid and setgid: mode readable");
      Files_Suite.Support.Assert_Equal
        (Mode, 8#1777#, "directory copies preserve sticky deletion protection while stripping setuid and setgid: mode");
   end Test_Copy_Access_Bits;
