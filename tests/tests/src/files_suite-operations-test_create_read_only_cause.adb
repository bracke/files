separate (Files_Suite.Operations)
   procedure Test_Create_Read_Only_Cause (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Locked : constant String := Join (Root, "locked");
      Mutation : Files.File_System.Mutation_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Directory (Locked);
      if not Lock_Directory (Locked) then
         Unlock_Directory (Locked);
         Files_Suite.Support.Skip ("Test_Create_Read_Only_Cause", "a read-only directory does not refuse writes here");
         return;
      end if;
      Mutation := Files.File_System.Create_Empty_File (Join (Locked, "new.txt"));
      Assert (not Mutation.Success, "a read-only folder refuses a new file");
      Assert_Equal (To_String (Mutation.Error_Key), "error.io.denied", "the refused file says permission was denied");
      Mutation := Files.File_System.Create_Directory (Join (Locked, "new folder"));
      Assert (not Mutation.Success, "a read-only folder refuses a new folder");
      Assert_Equal (To_String (Mutation.Error_Key), "error.io.denied", "the refused folder says permission was denied");
      Unlock_Directory (Locked);
      Assert (not Ada.Directories.Exists (Join (Locked, "new.txt"))
              and then not Ada.Directories.Exists (Join (Locked, "new folder")),
              "nothing is left behind");

      --  A failure the caller can name itself keeps its own key.
      Mutation := Files.File_System.Create_Empty_File (Join (Join (Root, "missing"), "new.txt"));
      Assert_Equal (To_String (Mutation.Error_Key), "error.file.parent_missing", "a missing parent keeps its key");
      Write_File (Join (Locked, "taken.txt"));
      Mutation := Files.File_System.Create_Empty_File (Join (Locked, "taken.txt"));
      Assert_Equal (To_String (Mutation.Error_Key), "error.file.exists", "an existing name keeps its key");
   exception
      when others =>
         Unlock_Directory (Locked);
         raise;
   end Test_Create_Read_Only_Cause;
