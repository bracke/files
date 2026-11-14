with Files.Protocol_Names;
separate (Files_Suite.Recovery)
   --  A registered stage with no payload and no restore or release marker may
   --  be one Preserve has registered but not yet filled -- perhaps in another
   --  process, while `files --list-recoveries` sweeps. The sweep leaves it,
   --  and its record, alone.
   procedure Test_Unmarked_Stage_Survives_Sweep (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dest   : constant String := Join (Root, "being-replaced.txt");
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
      begin
         --  As the stage looks between Preserve's Register and its move.
         Ada.Directories.Rename (To_String (Backup), Dest);
         Files.File_System.Sweep_Recovery_Registry;
         Assert (Ada.Directories.Exists (Stage), "an unmarked stage without its payload survives the sweep");
         Assert (Ada.Directories.Exists (Join (Stage, Files.Protocol_Names.Recovery_Owner)),
                 "its owner record is kept");
         --  Preserve completes: the payload arrives and is registered still.
         Ada.Directories.Rename (Dest, To_String (Backup));
         Assert (Files.File_System.Registered_Recovery_Payloads.Contains (Backup),
                 "the stage's record survived, so the payload is still found");
         Assert (Files.File_System.Delete_Trashed_Item (To_String (Backup)).Success,
                 "and the payload is discarded normally");
      end;
   end Test_Unmarked_Stage_Survives_Sweep;
