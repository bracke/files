separate (Files_Suite.Operations)
   procedure Test_Private_Copy_Stages (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : constant String := Join (Root, "source");
      Parent : constant String := Join (Root, "destination");
      Stage : constant String := Join (Parent, ".files-work-1");
      Seen : Boolean := False;
      Plans : Files.File_System.Drop_Import_Plan_Vectors.Vector;
      Mutation : Files.File_System.Mutation_Result;
      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Environment_Guard;
      function Observe return Boolean is
      begin
         if Ada.Directories.Exists (Join (Stage, "payload/secret")) then
            Seen := True;
            Assert (Is_Owner_Only (Stage), "staging remains owner-only while files are copied");
         end if;
         return False;
      end Observe;
   begin
      Files_Suite.Support.Save (Environment, "FILES_TRASH_BACKEND");
      if not Files.File_System.Supports_Permissions then
         Files_Suite.Support.Skip ("Test_Private_Copy_Stages", "not Files.File_System.Supports_Permissions");
         return;
      end if;
      Reset_Root;
      Ada.Directories.Create_Directory (Source);
      Ada.Directories.Create_Directory (Parent);
      Write_Binary_File (Join (Source, "secret"), "private content");
      Mutation := Files.File_System.Set_Permissions (Source, 8#700#);
      Assert (Mutation.Success, "make the source directory private");
      Mutation := Files.File_System.Set_Permissions (Join (Source, "secret"), 8#644#);
      Assert (Mutation.Success, "its child relies on the private ancestor");
      --  An existing stage belongs to another operation and must be skipped.
      Ada.Directories.Create_Directory (Stage);
      Write_Binary_File (Join (Stage, "unrelated"), "untouched");
      declare
         New_Stage : constant String := Files.Job_Context.Create_Stage (Parent);
      begin
         Assert
           (New_Stage /= Stage,
            "exclusive private staging does not change existing directories: new stage is distinct");
         Assert
           (Is_Owner_Only (New_Stage),
            "exclusive private staging does not change existing directories: new stage owner-only");
         Assert
           (File_Has_Bytes (Join (Stage, "unrelated"), "untouched"),
            "exclusive private staging does not change existing directories: existing stage untouched");
         Mutation := Files.File_System.Delete_Permanently (New_Stage);
         Assert (Mutation.Success, "remove the new empty stage");
      end;
      Mutation := Files.File_System.Delete_Permanently (Stage);
      Assert (Mutation.Success, "remove our collision fixture");
      Plans.Append (Files.File_System.Drop_Import_Plan'
        (To_Unbounded_String (Source), To_Unbounded_String (Join (Parent, "copy")),
         Files.File_System.Drop_Copy, True, Null_Unbounded_String));
      Mutation := Files.File_System.Execute_Drop_Import (Plans, Observe'Unrestricted_Access);
      Assert
        (Mutation.Success,
         "a private directory remains protected throughout copying and after publication: copy succeeded");
      Assert (Seen, "a private directory remains protected throughout copying and after publication: stage observed");
      Assert
        (Is_Owner_Only (Join (Parent, "copy")),
         "a private directory remains protected throughout copying and after publication: copy owner-only");
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "windows");
      declare
         Backup : Files.Types.UString;
      begin
         Mutation := Files.File_System.Preserve_For_Replace (Join (Parent, "copy"), Backup);
         Assert (Mutation.Success and then Is_Owner_Only
                 (Ada.Directories.Containing_Directory (To_String (Backup))),
                 "replacement recovery directories are private too");
         Mutation := Files.File_System.Restore_From_Trash (To_String (Backup));
         Assert (Mutation.Success, "restore the private replacement fixture");
      end;
   end Test_Private_Copy_Stages;
