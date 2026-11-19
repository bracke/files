with Files.File_System.Testing;
with Files.File_System.Permissions;
with Files_Suite.Volumes;
separate (Files_Suite.Transfer)
   --  A cross-device drop move whose source is set aside (its staging could
   --  neither finish nor be undone, as a replacement took its name) while
   --  the job is cancelled: the cancel does not mask that cause, for the
   --  copy had to stay and is the drop's result.
   procedure Test_Cancelled_Drop_Keeps_Cause (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Remote : Files_Suite.Volumes.Remote_Directory;
      Source : constant String := Join (Root, "set-aside-source");
      Destination : Unbounded_String;

      --  Cancelled once the replacement is there: after the copy, as the
      --  drop reads the failure.
      function Cancel_After_Set_Aside return Boolean is
        (Ada.Directories.Exists (Join (Source, "replacement")));

      procedure Cleanup is
         Mutation : Files.File_System.Mutation_Result;
         pragma Unreferenced (Mutation);
      begin
         Files.File_System.Testing.Stop_Failing_Directory_Restore;
         Mutation := Files.File_System.Permissions.Set_Permissions (Join (Root, ".files-recovery-1/payload"), 8#755#);
         Mutation := Files.File_System.Permissions.Set_Permissions (To_String (Destination), 8#755#);
         Mutation := Files.File_System.Permissions.Set_Permissions (Source, 8#755#);
      end Cleanup;
   begin
      if not Hostkit.Metadata.Mode_Bits_Are_Native then
         Files_Suite.Support.Skip
           ("Test_Cancelled_Drop_Keeps_Cause", "recovery records a folder's mode only where mode bits are native");
         return;
      end if;
      Reset_Root;
      Remote.Create ("files-test-cancelled-drop-");
      if Remote.Path = "" then
         Files_Suite.Support.Skip ("Test_Cancelled_Drop_Keeps_Cause", Files_Suite.Volumes.No_Other_Volume);
         return;
      end if;
      Destination := To_Unbounded_String (Join (Remote.Path, "moved"));
      Ada.Directories.Create_Directory (Source);
      Write_Binary_File (Join (Source, "child"), "original bytes");
      Assert
        (Files.File_System.Permissions.Set_Permissions (Source, 8#555#).Success, "prepare a read-only source");
      --  Setting the source aside cannot give it its mode back, and a
      --  replacement takes its name meanwhile: it stays in its stage.
      Files.File_System.Testing.Fail_Directory_Restore (Join (Root, ".files-recovery-1/payload"), Source);
      declare
         Plans    : Files.File_System.Drop_Import_Plan_Vectors.Vector;
         Mutation : Files.File_System.Mutation_Result;
      begin
         Plans.Append (Files.File_System.Drop_Import_Plan'
           (To_Unbounded_String (Source), Destination, Files.File_System.Drop_Move, True, Null_Unbounded_String));
         Mutation := Files.File_System.Testing.Execute_Drop_Import
           (Plans, Cancel_After_Set_Aside'Unrestricted_Access);
         Assert (not Mutation.Success, "a set-aside source fails the move");
         Files_Suite.Support.Assert_Equal
           (To_String (Mutation.Error_Key), "error.move.source_set_aside",
            "a cancel does not mask a set-aside source");
         Assert (File_Has_Bytes (Join (To_String (Destination), "child"), "original bytes"),
                 "the copy that had to stay is kept");
         Assert (File_Has_Bytes (Join (Root, ".files-recovery-1/payload/child"), "original bytes"),
                 "the source is kept in its stage");
         Assert (File_Has_Bytes (Join (Source, "replacement"), "replacement bytes"),
                 "the replacement is never touched");
      end;
      Cleanup;
   exception
      when others =>
         Cleanup;
         raise;
   end Test_Cancelled_Drop_Keeps_Cause;
