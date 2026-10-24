separate (Files_Suite.Operations)
   procedure Test_Cleanup_Exit_Verification (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Variable  : constant String := "FILES_TEST_SKIP_CLEANUP_ONCE";
      Had_Value : constant Boolean := Ada.Environment_Variables.Exists (Variable);
      Old_Value : constant String := Ada.Environment_Variables.Value (Variable, "");
      Marker    : constant String := Join (Root, "cleanup-worker-skipped");
      Job       : Files.Process_Jobs.Session;
      Transport : Files.Types.UString;

      procedure Restore is
      begin
         if Had_Value then
            Ada.Environment_Variables.Set (Variable, Old_Value);
         else
            Ada.Environment_Variables.Clear (Variable);
         end if;
         if Length (Transport) > 0 and then Ada.Directories.Exists (To_String (Transport)) then
            Project_Tools.Files.Delete_Tree (To_String (Transport));
         end if;
         if Ada.Directories.Exists (Marker) then
            Ada.Directories.Delete_File (Marker);
         end if;
      end Restore;
   begin
      Reset_Root;
      Ada.Environment_Variables.Set (Variable, Marker);
      Files.Process_Jobs.Reserve (Job);
      Transport := To_Unbounded_String (Files.Process_Jobs.Path (Job, ""));
      Ada.Directories.Create_Directory (Join (To_String (Transport), "stages"));
      Files.Process_Jobs.Reset (Job);

      for Attempt in 1 .. 5_000 loop
         exit when Ada.Directories.Exists (Marker);
         delay 0.001;
      end loop;
      Assert
        (Ada.Directories.Exists (Marker)
         and then Ada.Directories.Exists (To_String (Transport)),
         "a zero-exit cleanup helper can leave its transport behind");

      for Attempt in 1 .. 10_000 loop
         exit when not Ada.Directories.Exists (To_String (Transport));
         delay 0.001;
      end loop;
      Assert
        (not Ada.Directories.Exists (To_String (Transport)),
         "the reaper retries when a zero-exit cleanup helper leaves its transport behind");
      Restore;
   exception
      when others =>
         Restore;
         raise;
   end Test_Cleanup_Exit_Verification;
