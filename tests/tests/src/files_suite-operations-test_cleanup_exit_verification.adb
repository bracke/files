separate (Files_Suite.Operations)
   procedure Test_Cleanup_Exit_Verification (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Variable  : constant String := "FILES_TEST_SKIP_CLEANUP_ONCE";
      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Environment_Guard;
      Marker    : constant String := Join (Root, "cleanup-worker-skipped");
      Job       : Files.Process_Jobs.Session;
      Transport : Files.Types.UString;

      procedure Clean_Up is
      begin
         if Length (Transport) > 0 and then Ada.Directories.Exists (To_String (Transport)) then
            Project_Tools.Files.Delete_Tree (To_String (Transport));
         end if;
         if Ada.Directories.Exists (Marker) then
            Ada.Directories.Delete_File (Marker);
         end if;
      end Clean_Up;
   begin
      Files_Suite.Support.Save (Environment, Variable);
      Reset_Root;
      Ada.Environment_Variables.Set (Variable, Marker);
      Files.Process_Jobs.Reserve (Job);
      Transport := To_Unbounded_String (Files.Process_Jobs.Path (Job, ""));
      Ada.Directories.Create_Directory (Join (To_String (Transport), "stages"));
      Files.Process_Jobs.Reset (Job);

      for Attempt in Files_Suite.Support.Polling loop
         exit when Ada.Directories.Exists (Marker);
      end loop;
      Assert
        (Ada.Directories.Exists (Marker),
         "a zero-exit cleanup helper can leave its transport behind: the helper ran");
      Assert
        (Ada.Directories.Exists (To_String (Transport)),
         "a zero-exit cleanup helper can leave its transport behind: the transport remains");

      for Attempt in Files_Suite.Support.Polling loop
         exit when not Ada.Directories.Exists (To_String (Transport));
      end loop;
      Assert
        (not Ada.Directories.Exists (To_String (Transport)),
         "the reaper retries when a zero-exit cleanup helper leaves its transport behind");
      Clean_Up;
   exception
      when others =>
         Clean_Up;
         raise;
   end Test_Cleanup_Exit_Verification;
