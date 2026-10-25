separate (Files_Suite.Operations)
   procedure Test_Helper_Lease_Survives_Parent
     (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Job_Cleanup.Cleanup_Outcome;
      Directory : Files.Types.UString;
      Identity : Files.Types.UString;
      Recovery_Owner : Files.Job_Transports.Lease;
      Arguments : Hostkit.String_Vectors.Vector;
      Exit_Status : Integer;
      Outcome : Files.Job_Transports.Claim_Outcome := Files.Job_Transports.Claim_Refused;
      Report_Path : constant String := Join (Root, "helper-lease-transport");
      Ready_Path : constant String := Join (Root, "helper-lease-ready");
      Release_Path : constant String := Join (Root, "helper-lease-release");
      Refused_Path : constant String := Join (Root, "helper-lease-refused");
      File : Ada.Text_IO.File_Type;
   begin
      Reset_Root;
      Arguments.Append (To_Unbounded_String ("--files-test-crash-with-helper"));
      Arguments.Append (To_Unbounded_String (Report_Path));
      Arguments.Append (To_Unbounded_String (Ready_Path));
      Arguments.Append (To_Unbounded_String (Release_Path));
      Assert
        (Hostkit.Process.Run (Hostkit.Fs.Own_Executable, Arguments, Exit_Status),
         "the parent exits abruptly after its helper joins the lease: the parent runs");
      Files_Suite.Support.Assert_Equal
        (Exit_Status, 0, "the parent exits abruptly after its helper joins the lease: exit status");
      Assert
        (Ada.Directories.Exists (Ready_Path),
         "the parent exits abruptly after its helper joins the lease: the helper joined");
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Report_Path);
      Directory := To_Unbounded_String (Ada.Text_IO.Get_Line (File));
      Ada.Text_IO.Close (File);
      Identity := To_Unbounded_String
        (Files.Job_Transports.Recorded_Identity (To_String (Directory)));
      Assert
        (Files.Job_Transports.Claim_Abandoned
           (To_String (Directory), To_String (Identity), Recovery_Owner) =
             Files.Job_Transports.Claim_Busy,
         "recovery cannot claim the transport after the parent crashes while its helper lives");
      Write_Binary_File (Release_Path, "release");
      for Attempt in Files_Suite.Support.Polling loop
         Outcome := Files.Job_Transports.Claim_Abandoned
           (To_String (Directory), To_String (Identity), Recovery_Owner);
         exit when Outcome = Files.Job_Transports.Claim_Acquired;
      end loop;
      Assert
        (Outcome = Files.Job_Transports.Claim_Acquired,
         "recovery acquires the transport after the helper exits");
      Assert
        (Files.Job_Transports.Retire (Recovery_Owner, To_String (Directory)),
         "recovery durably closes helper admission before releasing its lease");
      Files.Job_Transports.Release (Recovery_Owner);
      Arguments.Clear;
      Arguments.Append (To_Unbounded_String ("--files-test-lease-holder"));
      Arguments.Append (Directory);
      Arguments.Append (To_Unbounded_String (Refused_Path));
      Arguments.Append (To_Unbounded_String (Release_Path));
      Assert
        (not Hostkit.Process.Run (Hostkit.Fs.Own_Executable, Arguments, Exit_Status),
         "a helper cannot join a retiring transport after recovery releases its lease: the helper fails");
      Files_Suite.Support.Assert_Equal
        (Exit_Status, 2, "a helper cannot join a retiring transport after recovery releases its lease: exit status");
      Assert
        (not Ada.Directories.Exists (Refused_Path),
         "a helper cannot join a retiring transport after recovery releases its lease: no refusal marker");
      Assert
        (Files.Job_Cleanup.Run (To_String (Directory), To_String (Identity)) =
           Files.Job_Cleanup.Cleanup_Removed,
         "recovery removes the transport after both owners have exited");
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         if not Ada.Directories.Exists (Release_Path) then
            Write_Binary_File (Release_Path, "release");
         end if;
         Files.Job_Transports.Release (Recovery_Owner);
         raise;
   end Test_Helper_Lease_Survives_Parent;
