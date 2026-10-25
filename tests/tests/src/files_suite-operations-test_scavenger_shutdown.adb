separate (Files_Suite.Operations)
   procedure Test_Scavenger_Shutdown (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Active          : Files.Process_Jobs.Session;
      Shutdown_Control : constant String := Join (Root, "shutdown-coordinator");
      Had_Scavenge_Stall : constant Boolean :=
        Ada.Environment_Variables.Exists ("FILES_TEST_STALL_SCAVENGER");
      Old_Scavenge_Stall : constant String :=
        Ada.Environment_Variables.Value ("FILES_TEST_STALL_SCAVENGER", "");

      procedure Restore is
      begin
         if Had_Scavenge_Stall then
            Ada.Environment_Variables.Set ("FILES_TEST_STALL_SCAVENGER", Old_Scavenge_Stall);
         else
            Ada.Environment_Variables.Clear ("FILES_TEST_STALL_SCAVENGER");
         end if;
         if Ada.Directories.Exists (Shutdown_Control & ".started")
           and then not Ada.Directories.Exists (Shutdown_Control & ".release")
         then
            Write_Binary_File (Shutdown_Control & ".release", "release");
         end if;
         Files.Process_Jobs.Reset (Active);
      end Restore;
   begin
      Reset_Root;
      --  A live job keeps its transport present, as it is during startup recovery.
      Files.Process_Jobs.Reserve (Active);

      Assert
        (Files.Job_Scavenger.Run (Wait_For_Grace => False),
         "scavenging reports completion when only a live claimed transport remains");

      Ada.Environment_Variables.Set ("FILES_TEST_STALL_SCAVENGER", Shutdown_Control);
      for Attempt in Files_Suite.Support.Polling (Interval => 0.05) loop
         Files.Job_Scavenger.Scavenge;
         exit when Ada.Directories.Exists (Shutdown_Control & ".started");
      end loop;
      Assert (Ada.Directories.Exists (Shutdown_Control & ".started"),
              "shutdown fixture starts a coordinator that waits for release");
      declare
         File : Ada.Text_IO.File_Type;
         Child_Id : Integer;
         Reaped : Boolean;
      begin
         Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Shutdown_Control & ".started");
         Child_Id := Integer'Value (Ada.Text_IO.Get_Line (File));
         Ada.Text_IO.Close (File);
         Files.Job_Scavenger.Shutdown (Reaped);
         Assert (Reaped, "shutdown reports a reaped coordinator");
         if Hostkit.Host.Current = Hostkit.Host.Linux
           and then Ada.Directories.Exists ("/proc/self")
         then
            Assert
              (not Ada.Directories.Exists
                 ("/proc/" & Ada.Strings.Fixed.Trim (Integer'Image (Child_Id), Ada.Strings.Both)),
               "shutdown reaps the coordinator before returning");
         end if;
      exception
         when others =>
            if Ada.Text_IO.Is_Open (File) then
               Ada.Text_IO.Close (File);
            end if;
            raise;
      end;
      Restore;
   exception
      when others =>
         Restore;
         raise;
   end Test_Scavenger_Shutdown;
