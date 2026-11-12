separate (Files_Suite.Operations)
   --  A restore that put the original back but could not remove its stage
   --  keeps the registry record, and the next sweep of the registry finishes
   --  the stage, as Release finishes one whose payload already left.
   procedure Test_Emptied_Stage_Swept (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dest   : constant String := Join (Root, "restored.txt");
      Backup : Files.Types.UString;
      Result : Files.File_System.Mutation_Result;
      Environment : Files_Suite.Support.Environment_Guard;
   begin
      Files_Suite.Support.Save (Environment, "FILES_TRASH_BACKEND");
      Reset_Root;
      --  A native backend keeps a replaced original in a private recovery folder.
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "windows");
      Write_Binary_File (Dest, "original");
      Result := Files.File_System.Preserve_For_Replace (Dest, Backup);
      Assert (Result.Success and then Files.File_System.Is_Recovery_Payload (To_String (Backup)),
              "an original is kept for recovery");
      declare
         Stage : constant String := Ada.Directories.Containing_Directory (To_String (Backup));
         Payloads : Files.Types.String_Vectors.Vector;
      begin
         --  The payload moved back, the stage left behind.
         Ada.Directories.Rename (To_String (Backup), Join (Root, "restored-by-hand"));
         Assert (Ada.Directories.Exists (Stage), "the emptied stage is still there before the sweep");
         Payloads := Files.File_System.Registered_Recovery_Payloads;
         Assert (not Payloads.Contains (Backup), "a stage without its payload is no registered payload");
         Assert (not Ada.Directories.Exists (Stage), "the sweep removes the emptied stage");
         Assert (not Files.File_System.Registered_Recovery_Payloads.Contains (Backup),
                 "and a later sweep finds nothing of it");
      end;
      Assert (Project_Tools.Files.Read_Raw_File (Join (Root, "restored-by-hand")) = "original",
              "the payload itself is untouched");
   end Test_Emptied_Stage_Swept;
