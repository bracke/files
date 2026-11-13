with Hostkit.Locks;
with Files.Protocol_Names;
separate (Files_Suite.Operations)
   --  Every change to the recovery registry takes its lock, so two processes
   --  never act on one slot at once: one could otherwise delete a slot the
   --  other had just reclaimed under the same name, and that one's record --
   --  and the Undo depending on it -- failed. A sweep started while someone
   --  else holds the lock waits for it, and goes ahead once it is let go.
   procedure Test_Registry_Changes_Wait_For_Its_Lock (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Hostkit.Locks.Lock_Outcome;
      Test_Temp   : constant String := Ada.Environment_Variables.Value ("FILES_TEST_TEMP", Root & "_temp");
      Environment : Files_Suite.Support.Environment_Guard;
      Registry    : constant String := Join (Join (Join (Test_Temp, "data"), "files"), "recovery-index");
      Held        : Hostkit.Locks.Lock;

      protected Sweep_State is
         procedure Finish;
         function Finished return Boolean;
      private
         Done : Boolean := False;
      end Sweep_State;

      protected body Sweep_State is
         procedure Finish is
         begin
            Done := True;
         end Finish;

         function Finished return Boolean is (Done);
      end Sweep_State;
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
      declare
         task Sweeper;

         task body Sweeper is
         begin
            Files.File_System.Sweep_Recovery_Registry;
            Sweep_State.Finish;
         exception
            when others =>
               Sweep_State.Finish;
         end Sweeper;
      begin
         delay 0.5;
         Assert (not Sweep_State.Finished, "a registry sweep waits while another holds the registry's lock");
         Hostkit.Locks.Release (Held);
         for Attempt in Files_Suite.Support.Polling loop
            exit when Sweep_State.Finished;
         end loop;
         Assert (Sweep_State.Finished, "and goes ahead once the lock is let go");
      end;
   exception
      when others =>
         Hostkit.Locks.Release (Held);
         raise;
   end Test_Registry_Changes_Wait_For_Its_Lock;
