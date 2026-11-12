with Files.Protocol_Names;
separate (Files_Suite.Operations)
   --  A release still running holds its stage's marker as a lease: the
   --  registry sweep (perhaps from `files --list-recoveries` in another
   --  process) leaves its payload where the release put it, and resumes the
   --  release only once nothing holds the marker any more.
   procedure Test_Held_Release_Marker_Skipped (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dest   : constant String := Join (Root, "being-released.txt");
      Backup : Files.Types.UString;
      Result : Files.File_System.Mutation_Result;
      Marker : Hostkit.Lease_Files.Lease;
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
         Stage  : constant String := Ada.Directories.Containing_Directory (To_String (Backup));
         Holder : constant String := Join (Stage, "release");
         Held   : constant String := Join (Holder, "being-released.txt");
      begin
         --  As a live release leaves the stage while it trashes the payload.
         Assert (Hostkit.Lease_Files.Create (Join (Stage, Files.Protocol_Names.Recovery_Releasing), Marker) =
                   Hostkit.Lease_Files.Opened,
                 "the release marker is made and held");
         Ada.Directories.Create_Directory (Holder);
         Ada.Directories.Rename (To_String (Backup), Held);
         Files.File_System.Sweep_Recovery_Registry;
         Assert (Ada.Directories.Exists (Held), "a held release marker keeps the sweep from moving the payload back");
         Assert (not Ada.Directories.Exists (To_String (Backup)), "the payload slot stays empty while it is held");
         Assert (Ada.Directories.Exists (Stage), "nor does the sweep remove the stage");
         Assert (not Files.File_System.Release_Recovery_Payload (To_String (Backup)).Success,
                 "a second release of the same payload is refused while the first holds the marker");
         Assert (Ada.Directories.Exists (Held), "and it leaves the held payload alone");

         --  The releasing process stops: its lease goes with it.
         Hostkit.Lease_Files.Release (Marker);
         Files.File_System.Sweep_Recovery_Registry;
         Files_Suite.Support.Assert_Equal
           (Project_Tools.Files.Read_Raw_File (To_String (Backup)), "original",
            "once nothing holds the marker, the sweep resumes the release and puts the payload back");
         Assert (not Ada.Directories.Exists (Holder), "the release folder is gone again");
         Assert (Files.File_System.Registered_Recovery_Payloads.Contains (Backup),
                 "the payload is registered and recoverable again");
         Assert (Files.File_System.Delete_Trashed_Item (To_String (Backup)).Success,
                 "and it is discarded normally");
      end;
   exception
      when others =>
         Hostkit.Lease_Files.Release (Marker);
         raise;
   end Test_Held_Release_Marker_Skipped;
