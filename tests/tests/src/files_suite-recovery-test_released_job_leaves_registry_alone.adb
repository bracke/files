with Hostkit.Locks;
with Files.Protocol_Names;
separate (Files_Suite.Recovery)
   --  A job's transport is a private temporary folder of protocol files: the
   --  last release hands it to the orphan reaper, which removes it without a
   --  recovery record. So releasing a job never waits on the recovery
   --  registry, and the transport goes even while another process holds the
   --  registry's lock.
   procedure Test_Released_Job_Leaves_Registry_Alone (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Hostkit.Locks.Lock_Outcome;
      Test_Temp   : constant String := Ada.Environment_Variables.Value ("FILES_TEST_TEMP", Root & "_temp");
      Environment : Files_Suite.Support.Environment_Guard;
      Registry    : constant String := Join (Join (Join (Test_Temp, "data"), "files"), "recovery-index");
      Held        : Hostkit.Locks.Lock;
      Job         : Files.Process_Jobs.Session;
      Transport   : Unbounded_String;
   begin
      if not Ada.Environment_Variables.Exists ("FILES_TEST_TEMP") then
         Files_Suite.Support.Save (Environment, "FILES_TEST_TEMP");
         Ada.Environment_Variables.Set ("FILES_TEST_TEMP", Test_Temp);
      end if;
      Reset_Root;
      Ada.Directories.Create_Path (Registry);
      Assert
        (Hostkit.Locks.Acquire
           (Join (Registry, Files.Protocol_Names.Recovery_Registry_Lock),
            Hostkit.Locks.Lock_Exclusive, Wait => False, Item => Held) = Hostkit.Locks.Lock_Ok,
         "the test holds the registry lock");

      Files.Process_Jobs.Reserve (Job);
      Transport := To_Unbounded_String (Files.Process_Jobs.Path (Job, ""));
      Write_Binary_File (Files.Process_Jobs.Path (Job, Files.Process_Jobs.Result_File), "result");
      Files.Process_Jobs.Reset (Job);
      for Attempt in Files_Suite.Support.Polling loop
         exit when not Ada.Directories.Exists (To_String (Transport));
      end loop;
      Assert (not Ada.Directories.Exists (To_String (Transport)),
              "the released transport is removed while the registry is locked");
      Hostkit.Locks.Release (Held);
   exception
      when others =>
         Hostkit.Locks.Release (Held);
         Files.Process_Jobs.Reset (Job);
         raise;
   end Test_Released_Job_Leaves_Registry_Alone;
