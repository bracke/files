with Files.File_System.Testing;
with Files.Protocol_Names;
separate (Files_Suite.Operations)
   --  A sweep reads and changes the registry under its lock, but lets it go
   --  for the work a record leads to -- putting a stopped release's payload
   --  back, a trash move, a stage's removal -- which can take long. Preserve
   --  registers from the window, so a Register started meanwhile must not
   --  wait for that work; the sweep still finishes its work afterwards.
   procedure Test_Sweep_Leaves_Registry_Open (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Test_Temp   : constant String := Ada.Environment_Variables.Value ("FILES_TEST_TEMP", Root & "_temp");
      Environment : Files_Suite.Support.Environment_Guard;
      Dest        : constant String := Join (Root, "swept.txt");
      Other       : constant String := Join (Root, "registered.txt");
      Backup      : Files.Types.UString;
      Result      : Files.File_System.Mutation_Result;

      protected State is
         procedure Finish_Sweep;
         function Sweep_Finished return Boolean;
         procedure Finish_Register (Succeeded : Boolean; Payload : Files.Types.UString);
         function Register_Finished return Boolean;
         function Register_Succeeded return Boolean;
         function Registered return Files.Types.UString;
      private
         Swept, Done, Success : Boolean := False;
         Kept : Files.Types.UString;
      end State;

      protected body State is
         procedure Finish_Sweep is
         begin
            Swept := True;
         end Finish_Sweep;

         function Sweep_Finished return Boolean is (Swept);

         procedure Finish_Register (Succeeded : Boolean; Payload : Files.Types.UString) is
         begin
            Done := True;
            Success := Succeeded;
            Kept := Payload;
         end Finish_Register;

         function Register_Finished return Boolean is (Done);
         function Register_Succeeded return Boolean is (Success);
         function Registered return Files.Types.UString is (Kept);
      end State;

      --  A marker as a stopped release leaves it: made as a lease, its holder gone.
      procedure Leave_Marker (Path : String) is
         Marker : Hostkit.Lease_Files.Lease;
      begin
         Assert (Hostkit.Lease_Files.Create (Path, Marker) = Hostkit.Lease_Files.Opened, "a marker lease is made");
         Hostkit.Lease_Files.Release (Marker);
      end Leave_Marker;
   begin
      Files_Suite.Support.Save (Environment, "FILES_TRASH_BACKEND");
      if not Ada.Environment_Variables.Exists ("FILES_TEST_TEMP") then
         Files_Suite.Support.Save (Environment, "FILES_TEST_TEMP");
         Ada.Environment_Variables.Set ("FILES_TEST_TEMP", Test_Temp);
      end if;
      Reset_Root;
      --  A native backend keeps a replaced original in a private recovery folder.
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "windows");
      Write_Binary_File (Dest, "swept");
      Write_Binary_File (Other, "registered");
      Result := Files.File_System.Preserve_For_Replace (Dest, Backup);
      Assert (Result.Success and then Files.File_System.Is_Recovery_Payload (To_String (Backup)),
              "an original is kept for recovery");
      declare
         Stage  : constant String := Ada.Directories.Containing_Directory (To_String (Backup));
         Holder : constant String := Join (Stage, "release");
      begin
         --  A release stopped after its first move: the sweep's work is to
         --  put the held entry back.
         Ada.Directories.Create_Directory (Holder);
         Ada.Directories.Rename (To_String (Backup), Join (Holder, "swept.txt"));
         Leave_Marker (Join (Stage, Files.Protocol_Names.Recovery_Releasing));
         Files.File_System.Testing.Pause_Sweep_Work;
         declare
            task Sweeper;

            task body Sweeper is
            begin
               Files.File_System.Sweep_Recovery_Registry;
               State.Finish_Sweep;
            exception
               when others =>
                  State.Finish_Sweep;
            end Sweeper;
         begin
            for Attempt in Files_Suite.Support.Polling loop
               exit when Files.File_System.Testing.Sweep_Work_Paused;
            end loop;
            Assert (Files.File_System.Testing.Sweep_Work_Paused, "the sweep reaches its work on the payload");
            declare
               task Registrar;

               task body Registrar is
                  Kept    : Files.Types.UString;
                  Outcome : Files.File_System.Mutation_Result;
               begin
                  Outcome := Files.File_System.Preserve_For_Replace (Other, Kept);
                  State.Finish_Register (Outcome.Success, Kept);
               exception
                  when others =>
                     State.Finish_Register (False, Files.Types.UString'(Null_Unbounded_String));
               end Registrar;
            begin
               for Attempt in Files_Suite.Support.Polling loop
                  exit when State.Register_Finished;
               end loop;
               --  Assert only once both tasks can end, whatever the outcome.
               declare
                  Registered_Meanwhile : constant Boolean := State.Register_Finished;
                  Sweep_Still_Held     : constant Boolean := not State.Sweep_Finished;
               begin
                  Files.File_System.Testing.Resume_Sweep_Work;
                  Assert (Registered_Meanwhile, "a Register while the sweep works does not wait for the sweep");
                  Assert (Sweep_Still_Held, "the sweep was still at its work then");
               end;
            end;
            for Attempt in Files_Suite.Support.Polling loop
               exit when State.Sweep_Finished;
            end loop;
            Assert (State.Sweep_Finished, "the sweep finishes once its work goes on");
         end;
         Assert (State.Register_Succeeded, "the second original is kept for recovery");
         Files_Suite.Support.Assert_Equal
           (Project_Tools.Files.Read_Raw_File (To_String (Backup)),
            "swept",
            "the sweep still put the held original back in its payload slot");
         Assert (Files.File_System.Registered_Recovery_Payloads.Contains (Backup),
                 "and its record is kept");
         Assert (Files.File_System.Registered_Recovery_Payloads.Contains (State.Registered),
                 "the payload registered meanwhile is recorded too");
      end;
   exception
      when others =>
         Files.File_System.Testing.Resume_Sweep_Work;
         raise;
   end Test_Sweep_Leaves_Registry_Open;
