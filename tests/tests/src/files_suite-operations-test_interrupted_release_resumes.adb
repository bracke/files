separate (Files_Suite.Operations)
   --  The halves of a release that a crash can interrupt, on every host: the
   --  trash need not be reachable to put a payload back, or to finish a
   --  release whose payload already left.
   procedure Test_Interrupted_Release_Resumes (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dest   : constant String := Join (Root, "replaced.txt");
      Backup : Files.Types.UString;
      Result : Files.File_System.Mutation_Result;
      Environment : Files_Suite.Support.Environment_Guard;
   begin
      Files_Suite.Support.Save (Environment, "FILES_TRASH_BACKEND");
      Reset_Root;
      --  A native backend keeps a replaced original in a private recovery folder.
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "windows");

      --  A release stopped after its first move leaves the payload under
      --  release/; the next look at the stage puts it back.
      Write_Binary_File (Dest, "second");
      Result := Files.File_System.Preserve_For_Replace (Dest, Backup);
      Assert (Result.Success and then Files.File_System.Is_Recovery_Payload (To_String (Backup)),
              "an original is kept for recovery");
      declare
         Stage  : constant String := Ada.Directories.Containing_Directory (To_String (Backup));
         Holder : constant String := Join (Stage, "release");
      begin
         Ada.Directories.Create_Directory (Holder);
         Ada.Directories.Rename (To_String (Backup), Join (Holder, "replaced.txt"));
         Assert (Files.File_System.Registered_Recovery_Payloads.Contains (Backup),
                 "an interrupted release is still a registered payload");
         Files_Suite.Support.Assert_Equal
           (Project_Tools.Files.Read_Raw_File (To_String (Backup)),
            "second",
            "the held original is back in its payload slot");
         Assert (not Ada.Directories.Exists (Holder), "the release folder is gone again");
      end;
      --  Out of the way of the next case, as a finished release would leave it.
      Ada.Directories.Rename (To_String (Backup), Join (Root, "second-released"));
      Result := Files.File_System.Release_Recovery_Payload (To_String (Backup));
      Assert (Result.Success, "and once it is gone the stage is finished with");

      --  A release stopped after the payload left its stage (to the trash, or
      --  beside the original) but before the stage went: the next release
      --  finishes by removing the stage and forgetting the payload.
      Write_Binary_File (Dest, "third");
      Result := Files.File_System.Preserve_For_Replace (Dest, Backup);
      Assert (Result.Success, "a third original is kept for recovery");
      Ada.Directories.Rename (To_String (Backup), Join (Root, "released-by-hand"));
      Result := Files.File_System.Release_Recovery_Payload (To_String (Backup));
      Assert (Result.Success, "an interrupted release whose payload already left is finished");
      Assert (not Ada.Directories.Exists (Ada.Directories.Containing_Directory (To_String (Backup))),
              "its stage is removed");
      Assert (not Files.File_System.Registered_Recovery_Payloads.Contains (Backup),
              "and the payload is no longer registered");
   end Test_Interrupted_Release_Resumes;
