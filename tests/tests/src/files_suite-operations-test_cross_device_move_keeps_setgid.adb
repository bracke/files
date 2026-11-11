with Files_Suite.Volumes;
separate (Files_Suite.Operations)
   --  A move across devices keeps setgid (and setuid) like a same-device
   --  rename does: the owner goes with the item, so the bits keep their
   --  meaning. A plain copy still drops them (Test_Copy_Access_Bits).
   procedure Test_Cross_Device_Move_Keeps_Setgid (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Remote    : Files_Suite.Volumes.Remote_Directory;
      Source    : constant String := Join (Root, "shared-project");
      Paths     : Files.File_System.Drop_Import_Plan_Vectors.Vector;
      Mutation  : Files.File_System.Mutation_Result;
      Available : Boolean;
      Mode      : Natural;
   begin
      if not Hostkit.Metadata.Mode_Bits_Are_Native then
         Files_Suite.Support.Skip ("Test_Cross_Device_Move_Keeps_Setgid", "needs native POSIX mode bits");
         return;
      end if;
      Reset_Root;
      Remote.Create ("files-test-setgid-move-");
      if Remote.Path = "" then
         Files_Suite.Support.Skip ("Test_Cross_Device_Move_Keeps_Setgid", Files_Suite.Volumes.No_Other_Volume);
         return;
      end if;
      Ada.Directories.Create_Directory (Source);
      Write_Binary_File (Join (Source, "notes.txt"), "shared");
      Mutation := Files.File_System.Set_Permissions (Source, 8#2775#);
      Assert (Mutation.Success, "prepare a setgid folder");
      Mode := Files.File_System.Permission_Bits_Of (Source, Available);
      Assert (Available, "the source mode is readable");
      Files_Suite.Support.Assert_Equal (Mode, 8#2775#, "the source folder is setgid");
      Paths.Append (Files.File_System.Drop_Import_Plan'
        (To_Unbounded_String (Source), To_Unbounded_String (Join (Remote.Path, "shared-project")),
         Files.File_System.Drop_Move, True, Null_Unbounded_String));
      Mutation := Files.File_System.Execute_Drop_Import (Paths);
      Assert (Mutation.Success, "the folder moves to the other volume");
      Mode := Files.File_System.Permission_Bits_Of (Join (Remote.Path, "shared-project"), Available);
      Assert (Available, "the moved folder's mode is readable");
      Files_Suite.Support.Assert_Equal (Mode, 8#2775#, "the moved folder keeps setgid");
      Assert (File_Has_Bytes (Join (Join (Remote.Path, "shared-project"), "notes.txt"), "shared"),
              "the moved folder keeps its file");
   end Test_Cross_Device_Move_Keeps_Setgid;
