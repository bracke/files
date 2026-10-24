separate (Files_Suite.Operations)
   procedure Test_Cleanup_Retry_Bound (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Variable  : constant String := "FILES_TEST_FAIL_CLEANUP_WORKER";
      Had_Value : constant Boolean := Ada.Environment_Variables.Exists (Variable);
      Old_Value : constant String := Ada.Environment_Variables.Value (Variable, "");
      Marker    : constant String := Join (Root, "cleanup-worker-failures");
      Job       : Files.Process_Jobs.Session;
      Transport : Files.Types.UString;

      function Failure_Count return Natural is
         Count : Natural := 0;
      begin
         if not Ada.Directories.Exists (Marker) then
            return 0;
         end if;
         declare
            Content : constant String := Project_Tools.Files.Read_Raw_File (Marker);
         begin
            for Character of Content loop
               if Character = Ada.Characters.Latin_1.LF then
                  Count := Count + 1;
               end if;
            end loop;
         end;
         return Count;
      end Failure_Count;

      procedure Restore is
      begin
         if Had_Value then
            Ada.Environment_Variables.Set (Variable, Old_Value);
         else
            Ada.Environment_Variables.Clear (Variable);
         end if;
         if Length (Transport) > 0 then
            if Hostkit.Fs.Is_Link (To_String (Transport)) then
               Ada.Directories.Delete_File (To_String (Transport));
            elsif Ada.Directories.Exists (To_String (Transport)) then
               Project_Tools.Files.Delete_Tree (To_String (Transport));
            end if;
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

      for Attempt in 1 .. 10_000 loop
         exit when Failure_Count >= 2;
         delay 0.001;
      end loop;
      Assert (Failure_Count = 2, "the parent makes its one bounded cleanup relaunch");

      delay 3.0;
      Assert
        (Failure_Count = 2 and then Ada.Directories.Exists (To_String (Transport)),
         "persistent cleanup refusal stops worker churn and leaves durable recovery state");
      Restore;

      if Hostkit.Host.Current = Hostkit.Host.Linux then
         Reset_Root;
         Ada.Environment_Variables.Set (Variable, Marker);
         Files.Process_Jobs.Reserve (Job);
         Transport := To_Unbounded_String (Files.Process_Jobs.Path (Job, ""));
         Files.Process_Jobs.Testing.Release_Owner (Job);
         Project_Tools.Files.Delete_Tree (To_String (Transport));
         Assert
           (Hostkit.Fs.Create_Link (Join (Root, "missing-transport-target"),
                                   To_String (Transport)),
            "replace a released transport with a dangling link");
         Files.Process_Jobs.Reset (Job);
         for Attempt in 1 .. 5_000 loop
            exit when Failure_Count >= 1;
            delay 0.001;
         end loop;
         Assert
           (Failure_Count >= 1 and then Hostkit.Fs.Is_Link (To_String (Transport)),
            "idle cleanup retains a dangling transport link for guarded retry");
         Restore;
      end if;
   exception
      when others =>
         Restore;
         raise;
   end Test_Cleanup_Retry_Bound;
