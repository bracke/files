with Ada.Directories;
with Ada.Streams.Stream_IO;
with Ada.Strings.Unbounded;

with Hostkit.Fs;
with Files.Durable_Writes;
with Files.Job_Context;
with Files.File_Identities;

package body Files.Transfer_Jobs is
   use Ada.Strings.Unbounded;

   function Is_Cancellation_Failure (Result : Job_Result) return Boolean is
     (not Result.Mutation.Success and then Length (Result.Trashed) = 0
      and then To_String (Result.Mutation.Error_Key) in "" | "error.drop.failed");

   procedure Start
     (Job    : in out Session;
      Action : Files.Paste.Resolved_Action;
      Mode   : Files.File_System.Drop_Import_Mode;
      Batch : Files.Copy_Context.Session := Files.Copy_Context.Empty_Session)
   is
      File : Ada.Streams.Stream_IO.File_Type;
   begin
      Files.Process_Jobs.Reserve (Job.Process);
      Ada.Streams.Stream_IO.Create
        (File, Ada.Streams.Stream_IO.Out_File, Files.Process_Jobs.Path (Job.Process, "request"));
      Files.Paste.Resolved_Action'Output (Ada.Streams.Stream_IO.Stream (File), Action);
      Files.File_System.Drop_Import_Mode'Output (Ada.Streams.Stream_IO.Stream (File), Mode);
      String'Output (Ada.Streams.Stream_IO.Stream (File), Files.Copy_Context.Directory (Batch));
      Ada.Streams.Stream_IO.Close (File);
      Files.Process_Jobs.Launch (Job.Process, "--files-transfer");
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (File) then
            Ada.Streams.Stream_IO.Close (File);
         end if;
         Reset (Job);
         raise;
   end Start;

   procedure Poll (Job : Session; Finished : out Boolean; Result : out Job_Result) is
      Cancelled : Boolean := False;
      File      : Ada.Streams.Stream_IO.File_Type;

      procedure Recover is
         Action : Files.Paste.Resolved_Action;
         Mode : Files.File_System.Drop_Import_Mode;
         Destinations, Sources, Identities, Tree_Revisions : Files.Types.String_Vectors.Vector;
         Backup_Identity : Files.Types.UString;
         use type Files.File_System.Drop_Import_Mode;
         procedure Close is
         begin
            if Ada.Streams.Stream_IO.Is_Open (File) then
               Ada.Streams.Stream_IO.Close (File);
            end if;
         end Close;
      begin
         begin
            Ada.Streams.Stream_IO.Open
              (File, Ada.Streams.Stream_IO.In_File, Files.Process_Jobs.Path (Job.Process, "completed"));
            Result := Job_Result'Input (Ada.Streams.Stream_IO.Stream (File));
            Close;
            Result.Recovered := True;
            Result.Cancelled := False;
            return;
         exception
            when others => Close;
         end;
         Ada.Streams.Stream_IO.Open
           (File, Ada.Streams.Stream_IO.In_File, Files.Process_Jobs.Path (Job.Process, "request"));
         Action := Files.Paste.Resolved_Action'Input (Ada.Streams.Stream_IO.Stream (File));
         Mode := Files.File_System.Drop_Import_Mode'Input (Ada.Streams.Stream_IO.Stream (File));
         Close;
         begin
            Ada.Streams.Stream_IO.Open
              (File, Ada.Streams.Stream_IO.In_File, Files.Process_Jobs.Path (Job.Process, "replaced"));
            declare
               Backup : constant String := String'Input (Ada.Streams.Stream_IO.Stream (File));
            begin
               Backup_Identity := To_Unbounded_String (String'Input (Ada.Streams.Stream_IO.Stream (File)));
               if Length (Backup_Identity) > 0
                 and then Files.File_Identities.Token (Backup) = To_String (Backup_Identity)
               then
                  Result.Trashed := To_Unbounded_String (Backup);
                  Result.Trashed_Identity := Backup_Identity;
               end if;
            end;
            Close;
         exception
            when others => Close;
         end;
         if Mode = Files.File_System.Drop_Move then
            Files.Job_Context.Read_Moved
              (Files.Process_Jobs.Path (Job.Process, ""), Destinations, Sources, Identities);
         else
            Files.Job_Context.Read_Created
              (Files.Process_Jobs.Path (Job.Process, ""), Destinations, Sources, Identities, Tree_Revisions);
         end if;
         for Index in Destinations.First_Index .. Destinations.Last_Index loop
            if Destinations (Index) = Action.Dest_Path and then Sources (Index) = Action.Source_Path
            then
               Result.Mutation := (Success => True, Error_Key => Null_Unbounded_String);
               Result.Created_Identity := Identities (Index);
               if Index <= Tree_Revisions.Last_Index then
                  Result.Created_Tree_Revision := Tree_Revisions (Index);
               end if;
               Result.Recovered := True;
               Result.Cancelled := False;
            end if;
         end loop;
      exception
         when others => Close;
      end Recover;
   begin
      Result := (others => <>);
      Files.Process_Jobs.Poll (Job.Process, Finished, Cancelled);
      if Finished then
         Ada.Streams.Stream_IO.Open
           (File, Ada.Streams.Stream_IO.In_File, Files.Process_Jobs.Path (Job.Process, "result"));
         Result := Job_Result'Input (Ada.Streams.Stream_IO.Stream (File));
         Ada.Streams.Stream_IO.Close (File);
         if not Result.Mutation.Success then
            Recover;
         end if;
         if Cancelled and then not Result.Mutation.Success then
            Result.Cancelled := Is_Cancellation_Failure (Result);
            if Length (Result.Trashed) > 0
              and then To_String (Result.Mutation.Error_Key) = "error.drop.failed"
            then
               Result.Mutation.Error_Key := To_Unbounded_String ("error.trash.restore_failed");
            end if;
         end if;
      end if;
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (File) then
            Ada.Streams.Stream_IO.Close (File);
         end if;
         Result.Mutation := (Success => False, Error_Key => To_Unbounded_String ("error.drop.failed"));
         Result.Cancelled := Cancelled and then Length (Result.Trashed) = 0;
         if Finished then
            Recover;
         end if;
   end Poll;

   procedure Cancel (Job : Session) is
   begin
      Files.Process_Jobs.Cancel (Job.Process);
   end Cancel;

   function Active (Job : Session) return Boolean is (Files.Process_Jobs.Active (Job.Process));

   procedure Reset (Job : in out Session) is
   begin
      Files.Process_Jobs.Reset (Job.Process);
   end Reset;

   procedure Run_Helper (Directory : String) is
      File   : Ada.Streams.Stream_IO.File_Type;
      Action : Files.Paste.Resolved_Action;
      Mode   : Files.File_System.Drop_Import_Mode;
      Result : Job_Result;
      Plans  : Files.File_System.Drop_Import_Plan_Vectors.Vector;
      Identities, Tree_Revisions : Files.Types.String_Vectors.Vector;
      Preserved : Boolean := False;
      Batch : Files.Copy_Context.Session;

      function Cancelled return Boolean is (Files.Process_Jobs.Cancellation_Requested (Directory));

      procedure Save is
         Output : Ada.Streams.Stream_IO.File_Type;
      begin
         Ada.Streams.Stream_IO.Create
           (Output, Ada.Streams.Stream_IO.Out_File, Hostkit.Fs.Join (Directory, "result.tmp"));
         Job_Result'Output (Ada.Streams.Stream_IO.Stream (Output), Result);
         Ada.Streams.Stream_IO.Close (Output);
         if not Files.Durable_Writes.Published
           (Files.Durable_Writes.Publish
              (Hostkit.Fs.Join (Directory, "result.tmp"), Hostkit.Fs.Join (Directory, "result")))
         then
            raise Ada.Directories.Use_Error;
         end if;
      end Save;

      procedure Roll_Back is
      begin
         if not Result.Mutation.Success and then Length (Result.Trashed) > 0 then
            declare
               Restored : constant Files.File_System.Mutation_Result :=
                 Files.File_System.Restore_From_Trash
                   (To_String (Result.Trashed), To_String (Result.Trashed_Identity), To_String (Action.Dest_Path));
            begin
               if Restored.Success then
                  Result.Trashed := Null_Unbounded_String;
                  Result.Trashed_Identity := Null_Unbounded_String;
               else
                  Result.Mutation := Restored;
               end if;
            end;
         end if;
      end Roll_Back;
   begin
      Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, Hostkit.Fs.Join (Directory, "request"));
      Action := Files.Paste.Resolved_Action'Input (Ada.Streams.Stream_IO.Stream (File));
      Mode := Files.File_System.Drop_Import_Mode'Input (Ada.Streams.Stream_IO.Stream (File));
      if not Ada.Streams.Stream_IO.End_Of_File (File) then
         Batch := Files.Copy_Context.Borrow (String'Input (Ada.Streams.Stream_IO.Stream (File)));
      end if;
      Ada.Streams.Stream_IO.Close (File);
      Save;
      begin
         if Cancelled then
            Result.Cancelled := True;
         elsif Action.Source_Path = Action.Dest_Path then
            Result.Mutation := (Success => False, Error_Key => To_Unbounded_String ("error.drop.into_self"));
         else
            if Action.Replaced then
               Result.Mutation := Files.File_System.Preserve_For_Replace (To_String (Action.Dest_Path), Result.Trashed);
               Preserved := Result.Mutation.Success;
               if Length (Result.Trashed) > 0 then
                  Result.Trashed_Identity := To_Unbounded_String
                    (Files.File_Identities.Token (To_String (Result.Trashed)));
                  --  Retain the replacement original independently of result checkpoints.
                  Ada.Streams.Stream_IO.Create
                    (File, Ada.Streams.Stream_IO.Out_File, Hostkit.Fs.Join (Directory, "replaced"));
                  String'Output (Ada.Streams.Stream_IO.Stream (File), To_String (Result.Trashed));
                  String'Output (Ada.Streams.Stream_IO.Stream (File),
                                 To_String (Result.Trashed_Identity));
                  Ada.Streams.Stream_IO.Close (File);
               end if;
               if Preserved then
                  Result.Mutation := (Success => False, Error_Key => To_Unbounded_String ("error.drop.failed"));
               end if;
               Save;
            end if;
            if not Action.Replaced or else Preserved then
               --  A checkpoint represents unfinished work until the write completes.
               Result.Mutation := (Success => False, Error_Key => To_Unbounded_String ("error.drop.failed"));
               Save;
               Plans.Append
                 (Files.File_System.Drop_Import_Plan'
                    (Source_Path      => Action.Source_Path,
                     Destination_Path => Action.Dest_Path,
                     Mode             => Mode,
                     Valid            => True,
                     Error_Key        => Null_Unbounded_String));
               Result.Mutation := Files.File_System.Execute_Drop_Import
                 (Plans, Identities, Tree_Revisions, Cancelled'Unrestricted_Access, Batch);
               if Result.Mutation.Success and then not Identities.Is_Empty then
                  Result.Created_Identity := Identities.First_Element;
                  Result.Created_Tree_Revision := Tree_Revisions.First_Element;
               end if;
               Roll_Back;
            end if;
         end if;
      exception
         when others =>
            Result.Mutation := (Success => False, Error_Key => To_Unbounded_String ("error.drop.failed"));
            Roll_Back;
      end;
      Result.Cancelled := Cancelled and then Is_Cancellation_Failure (Result);
      if Result.Mutation.Success then
         --  The result retains snapshots captured before publication even when
         --  the optional crash-recovery journal could not be extended.
         begin
            Ada.Streams.Stream_IO.Create
              (File, Ada.Streams.Stream_IO.Out_File, Hostkit.Fs.Join (Directory, "completed.tmp"));
            Job_Result'Output (Ada.Streams.Stream_IO.Stream (File), Result);
            Ada.Streams.Stream_IO.Close (File);
            declare
               Published : constant Files.Durable_Writes.Publication_Result := Files.Durable_Writes.Publish
                 (Hostkit.Fs.Join (Directory, "completed.tmp"), Hostkit.Fs.Join (Directory, "completed"));
               pragma Unreferenced (Published);
            begin
               null;
            end;
         exception
            when others =>
               if Ada.Streams.Stream_IO.Is_Open (File) then
                  Ada.Streams.Stream_IO.Close (File);
               end if;
         end;
      end if;
      Save;
   end Run_Helper;
end Files.Transfer_Jobs;
