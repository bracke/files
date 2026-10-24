separate (Files_Suite.Operations)
   procedure Test_Transport_Cleanup_Retry (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Job       : Files.Process_Jobs.Session;
      Transport : Files.Types.UString;
      Result    : Files.File_System.Mutation_Result;

      procedure Restore is
      begin
         if Length (Transport) > 0 and then Ada.Directories.Exists (To_String (Transport)) then
            Result := Files.File_System.Set_Permissions (To_String (Transport), 8#700#);
            Project_Tools.Files.Delete_Tree (To_String (Transport));
         end if;
      end Restore;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux or else Hostkit.Host.Is_Elevated then
         Files_Suite.Support.Skip
           ("Test_Transport_Cleanup_Retry",
            "Hostkit.Host.Current /= Hostkit.Host.Linux or else Hostkit.Host.Is_...");
         return;
      end if;

      Files.Process_Jobs.Reserve (Job);
      Transport := To_Unbounded_String (Files.Process_Jobs.Path (Job, ""));
      Write_Binary_File (Files.Process_Jobs.Path (Job, "ordinary-result"), "result");
      Result := Files.File_System.Set_Permissions (To_String (Transport), 0);
      Assert (Result.Success, "prepare an unreadable ordinary transport");

      Files.Process_Jobs.Reset (Job);
      Assert (Ada.Directories.Exists (To_String (Transport)),
              "the initial ordinary transport removal is forced to fail");
      Result := Files.File_System.Set_Permissions (To_String (Transport), 8#700#);
      Assert (Result.Success, "restore access for the cleanup retry");

      for Attempt in 1 .. 5_000 loop
         exit when not Ada.Directories.Exists (To_String (Transport));
         delay 0.001;
      end loop;
      Assert (not Ada.Directories.Exists (To_String (Transport)),
              "ordinary transport removal retries without a later job API call");

      Files.Process_Jobs.Reserve (Job);
      Transport := To_Unbounded_String (Files.Process_Jobs.Path (Job, ""));
      Files.Process_Jobs.Testing.Release_Owner (Job);
      declare
         Marker : constant String := Join (To_String (Transport), ".files-job-transport");
         Marker_Alias : constant String := Join (Root, "transport-marker-hardlink");
         Identity : Files.Types.UString;
         Read_Error : Boolean;
         Complete : Boolean;
      begin
         if Hostkit.Fs.Create_Hard_Link (Marker, Marker_Alias) then
            Files.Job_Transports.Inspect_Marker
              (To_String (Transport), Identity, Read_Error);
            Assert
              (not Read_Error and then Length (Identity) = 0
               and then Ada.Directories.Exists (To_String (Transport)),
               "marker inspection rejects a multiply-linked authority file");
            Ada.Directories.Delete_File (Marker_Alias);
         end if;
         Result := Files.File_System.Set_Permissions (Marker, 0);
         Assert (Result.Success, "prepare a temporarily unreadable transport marker");
         Files.Job_Transports.Inspect_Marker (To_String (Transport), Identity, Read_Error);
         Assert (Read_Error and then Length (Identity) = 0,
                 "marker inspection distinguishes read failure from invalid data");
         Complete := Files.Job_Scavenger.Run (Wait_For_Grace => False);
         Assert (not Complete and then Ada.Directories.Exists (To_String (Transport)),
                 "scavenging retries an unreadable marker instead of skipping it");
         Result := Files.File_System.Set_Permissions (Marker, 8#600#);
         Assert (Result.Success, "restore transport marker access");
         Complete := Files.Job_Scavenger.Run (Wait_For_Grace => False);
         Assert (Complete and then not Ada.Directories.Exists (To_String (Transport)),
                 "scavenging removes the transport after marker access returns");
      end;
      Files.Process_Jobs.Reset (Job);

      Files.Process_Jobs.Reserve (Job);
      Transport := To_Unbounded_String (Files.Process_Jobs.Path (Job, ""));
      Files.Process_Jobs.Testing.Release_Owner (Job);
      declare
         Lease_Path : constant String := Join (To_String (Transport), ".files-job-owner");
         Complete : Boolean;
      begin
         Result := Files.File_System.Set_Permissions (Lease_Path, 0);
         Assert (Result.Success, "prepare a temporarily inaccessible transport lease");
         Complete := Files.Job_Scavenger.Run (Wait_For_Grace => False);
         Assert (not Complete and then Ada.Directories.Exists (To_String (Transport)),
                 "scavenging retries a lease access failure");
         Result := Files.File_System.Set_Permissions (Lease_Path, 8#600#);
         Assert (Result.Success, "restore transport lease access");
         Complete := Files.Job_Scavenger.Run (Wait_For_Grace => False);
         Assert (Complete and then not Ada.Directories.Exists (To_String (Transport)),
                 "scavenging removes the transport after lease access returns");
      end;
      Files.Process_Jobs.Reset (Job);
   exception
      when others =>
         Restore;
         Files.Process_Jobs.Reset (Job);
         raise;
   end Test_Transport_Cleanup_Retry;
