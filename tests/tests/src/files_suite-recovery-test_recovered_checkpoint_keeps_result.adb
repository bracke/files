separate (Files_Suite.Recovery)
   procedure Test_Recovered_Checkpoint_Keeps_Result (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Reported_Backup : constant String := Join (Root, "reported-backup");
      Checkpoint_Backup : constant String := Join (Root, "checkpoint-backup");
      Checkpoint : constant String := Join (Root, "replaced");
      Result : Files.Transfer_Jobs.Job_Result;
   begin
      Reset_Root;
      Write_Binary_File (Reported_Backup, "reported destination");
      Result.Trashed := To_Unbounded_String (Reported_Backup);
      Result.Trashed_Identity := To_Unbounded_String (Files.File_Identities.Token (Reported_Backup));

      Files.Transfer_Jobs.Testing.Apply_Checkpoint (Checkpoint, Result);
      Assert
        (To_String (Result.Trashed) = Reported_Backup
         and then To_String (Result.Trashed_Identity) = Files.File_Identities.Token (Reported_Backup),
         "a missing checkpoint keeps the backup and identity the result reported");

      Write_Binary_File (Checkpoint, "not a checkpoint");
      Files.Transfer_Jobs.Testing.Apply_Checkpoint (Checkpoint, Result);
      Assert
        (To_String (Result.Trashed) = Reported_Backup
         and then To_String (Result.Trashed_Identity) = Files.File_Identities.Token (Reported_Backup),
         "an undecodable checkpoint keeps the backup and identity together");

      Write_Binary_File (Checkpoint_Backup, "checkpointed destination");
      Ada.Directories.Delete_File (Checkpoint);
      Files.Transfer_Jobs.Testing.Write_Checkpoint
        (Checkpoint, Checkpoint_Backup, Files.File_Identities.Token (Checkpoint_Backup));
      Files.Transfer_Jobs.Testing.Apply_Checkpoint (Checkpoint, Result);
      Assert
        (To_String (Result.Trashed) = Checkpoint_Backup
         and then To_String (Result.Trashed_Identity) = Files.File_Identities.Token (Checkpoint_Backup),
         "a valid checkpoint replaces the backup and identity together");
   end Test_Recovered_Checkpoint_Keeps_Result;
