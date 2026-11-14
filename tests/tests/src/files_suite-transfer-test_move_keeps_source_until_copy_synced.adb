with Files.Durability.Testing;
with Files_Suite.Volumes;
separate (Files_Suite.Transfer)
   --  A move across devices removes its source only once the copy is on the
   --  device: when syncing the copy fails, the source stays and the copy goes.
   procedure Test_Move_Keeps_Source_Until_Copy_Synced (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Remote   : Files_Suite.Volumes.Remote_Directory;
      Source   : constant String := Join (Root, "durable-source");
      Paths    : Files.File_System.Drop_Import_Plan_Vectors.Vector;
      Mutation : Files.File_System.Mutation_Result;
   begin
      Reset_Root;
      Remote.Create ("files-test-durable-move-");
      if Remote.Path = "" then
         Files_Suite.Support.Skip ("Test_Move_Keeps_Source_Until_Copy_Synced", Files_Suite.Volumes.No_Other_Volume);
         return;
      end if;
      for Folder in Boolean loop
         Reset_Root;
         if Folder then
            Ada.Directories.Create_Directory (Source);
            Write_Binary_File (Join (Source, "durable-child"), "the bytes");
         else
            Write_Binary_File (Source, "the bytes");
         end if;
         Paths.Clear;
         Paths.Append (Files.File_System.Drop_Import_Plan'
           (To_Unbounded_String (Source), To_Unbounded_String (Join (Remote.Path, "durable-destination")),
            Files.File_System.Drop_Move, True, Null_Unbounded_String));
         --  A file is flushed as it is written, while still staged under the
         --  name "payload"; a folder's file keeps its own name there.
         Files.Durability.Testing.Fail_Syncs_Ending_With (if Folder then "/durable-child" else "/payload");
         Mutation := Files.File_System.Execute_Drop_Import (Paths);
         Files.Durability.Testing.Clear;
         Assert (not Mutation.Success, "a copy that cannot be synced fails the move, folder " & Folder'Image);
         Assert (File_Has_Bytes ((if Folder then Join (Source, "durable-child") else Source), "the bytes"),
                 "the source stays, folder " & Folder'Image);
         Assert (not Ada.Directories.Exists (Join (Remote.Path, "durable-destination")),
                 "the unsynced copy is removed, folder " & Folder'Image);
      end loop;

      --  Without the fault the same move goes through.
      Reset_Root;
      Write_Binary_File (Source, "the bytes");
      Mutation := Files.File_System.Execute_Drop_Import (Paths);
      Assert (Mutation.Success, "a synced copy completes the move");
      Assert (not Ada.Directories.Exists (Source), "and removes the source");
      Assert (File_Has_Bytes (Join (Remote.Path, "durable-destination"), "the bytes"), "the copy holds the bytes");
   exception
      when others =>
         Files.Durability.Testing.Clear;
         raise;
   end Test_Move_Keeps_Source_Until_Copy_Synced;
