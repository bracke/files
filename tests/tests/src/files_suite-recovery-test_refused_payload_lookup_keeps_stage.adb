with Files.IO.Fs_Primitives.Testing;
with Files.Protocol_Names;
with Files_Suite.Support.Guards;
separate (Files_Suite.Recovery)
   --  A stopped release leaves its marker beside a payload still in place.
   --  If the host then refuses to look the payload up (a flaky share, a
   --  device not ready), the stage must not be taken for one whose payload
   --  left: neither a release nor the sweep may remove it, original inside,
   --  or forget its record.
   procedure Test_Refused_Payload_Lookup_Keeps_Stage (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dest        : constant String := Join (Root, "kept.txt");
      Backup      : Files.Types.UString;
      Result      : Files.File_System.Mutation_Result;
      Environment : Files_Suite.Support.Guards.Environment_Guard;
      Marker      : Hostkit.Lease_Files.Lease;
   begin
      Files_Suite.Support.Guards.Save (Environment, "FILES_TRASH_BACKEND");
      Reset_Root;
      --  A native backend keeps a replaced original in a private recovery folder.
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "windows");
      Write_Binary_File (Dest, "original");
      Result := Files.File_System.Preserve_For_Replace (Dest, Backup);
      Assert (Result.Success and then Files.File_System.Is_Recovery_Payload (To_String (Backup)),
              "an original is kept for recovery");
      declare
         Payload : constant String := To_String (Backup);
         Stage   : constant String := Ada.Directories.Containing_Directory (Payload);
      begin
         --  As a release stopped before the payload left leaves it.
         Assert
           (Hostkit.Lease_Files.Create (Join (Stage, Files.Protocol_Names.Recovery_Releasing), Marker) =
              Hostkit.Lease_Files.Opened,
            "a release marker is left");
         Hostkit.Lease_Files.Release (Marker);

         Files.IO.Fs_Primitives.Testing.Refuse_Lookups (Payload);
         Result := Files.File_System.Release_Recovery_Payload (Payload);
         Files.File_System.Sweep_Recovery_Registry;
         Files.IO.Fs_Primitives.Testing.Stop_Refusing_Lookups;

         Assert (not Result.Success, "a release that cannot see its payload does not finish");
         Assert (Ada.Directories.Exists (Payload), "the payload is still in its stage");
         Files_Suite.Support.Assert_Equal
           (Project_Tools.Files.Read_Raw_File (Payload), "original", "with the original's content");
         Assert (Files.File_System.Registered_Recovery_Payloads.Contains (Backup), "and still registered");

         --  Once the host answers again, a payload that did leave lets the
         --  stopped release finish: the stage goes, and so does its record.
         Ada.Directories.Rename (Payload, Join (Root, "released-by-hand"));
         Result := Files.File_System.Release_Recovery_Payload (Payload);
         Assert (Result.Success, "with the payload gone for sure, the stopped release finishes");
         Assert (not Ada.Directories.Exists (Stage), "its stage is removed");
         Assert (not Files.File_System.Registered_Recovery_Payloads.Contains (Backup), "and its record forgotten");
      end;
   exception
      when others =>
         Files.IO.Fs_Primitives.Testing.Stop_Refusing_Lookups;
         raise;
   end Test_Refused_Payload_Lookup_Keeps_Stage;
