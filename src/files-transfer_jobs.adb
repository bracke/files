with Files.Fs_Primitives;
with Files.Diagnostics;
with Ada.Directories;
with Ada.IO_Exceptions;
with Ada.Streams;
with Ada.Strings.Unbounded;

with GNAT.OS_Lib;

with Hostkit.Fs;
with Files.Bounded_Streams;
with Files.Exclusive_Streams;
with Files.Durable_Writes;
with Files.Job_Context;
with Files.File_Identities;
with Files.Lease_Streams;
with Hostkit.Lease_Files;

package body Files.Transfer_Jobs is
   use Ada.Strings.Unbounded;
   use type Ada.Directories.File_Kind;
   use type Hostkit.Lease_Files.Open_Outcome;

   Max_Transport_Path_Length : constant := 32 * 1024;
   Max_Transport_Token_Length : constant := 2 * 1024;
   Max_Transport_Error_Length : constant := 256;
   Request_Header : constant String := "files-transfer-request-1";
   Result_Header : constant String := "files-transfer-result-1";

   function Valid_Absolute_Path (Path : String) return Boolean is
     (Files.Fs_Primitives.Valid_Absolute_Path (Path));

   function Request_Is_Consistent
     (Action : Files.Paste.Resolved_Action;
      Batch_Directory : String) return Boolean is
   begin
      return Valid_Absolute_Path (To_String (Action.Source_Path))
        and then Valid_Absolute_Path (To_String (Action.Dest_Path))
        and then
          (Batch_Directory = ""
           or else Valid_Absolute_Path (Batch_Directory));
   end Request_Is_Consistent;

   function Result_Is_Consistent (Result : Job_Result) return Boolean is
      Success : constant Boolean := Result.Mutation.Success;
      Has_Trash : constant Boolean := Length (Result.Trashed) > 0;
      Has_Trash_Identity : constant Boolean := Length (Result.Trashed_Identity) > 0;
      Has_Created_Identity : constant Boolean := Length (Result.Created_Identity) > 0;
      Has_Created_Revision : constant Boolean := Length (Result.Created_Tree_Revision) > 0;
   begin
      return Has_Trash = Has_Trash_Identity
        and then (not Has_Trash
          or else Valid_Absolute_Path (To_String (Result.Trashed)))
        and then not Result.Recovered
        and then
          (if Success then
             Length (Result.Mutation.Error_Key) = 0
             and then not Result.Cancelled
             and then Has_Created_Identity
           else
             not Has_Created_Identity
             and then not Has_Created_Revision
             and then (not Result.Cancelled or else not Has_Trash));
   end Result_Is_Consistent;

   procedure Write_String
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Value : String;
      Max_Length : Natural)
   is
   begin
      if Value'Length > Max_Length then
         raise Ada.Directories.Use_Error;
      end if;
      String'Output (Stream, Value);
   end Write_String;

   procedure Write_Action
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Action : Files.Paste.Resolved_Action)
   is
   begin
      Write_String
        (Stream, To_String (Action.Source_Path), Max_Transport_Path_Length);
      Write_String
        (Stream, To_String (Action.Dest_Path), Max_Transport_Path_Length);
      Boolean'Output (Stream, Action.Skip);
      Boolean'Output (Stream, Action.Replaced);
   end Write_Action;

   function Read_Action
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class)
      return Files.Paste.Resolved_Action
   is
      Result : Files.Paste.Resolved_Action;
   begin
      Result.Source_Path := To_Unbounded_String
        (Files.Bounded_Streams.Input_String
           (Stream, Max_Transport_Path_Length));
      Result.Dest_Path := To_Unbounded_String
        (Files.Bounded_Streams.Input_String
           (Stream, Max_Transport_Path_Length));
      Result.Skip := Boolean'Input (Stream);
      Result.Replaced := Boolean'Input (Stream);
      return Result;
   end Read_Action;

   procedure Write_Request
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Action : Files.Paste.Resolved_Action;
      Mode : Files.File_System.Drop_Import_Mode;
      Batch_Directory : String)
   is
   begin
      if not Request_Is_Consistent (Action, Batch_Directory) then
         raise Ada.Directories.Use_Error;
      end if;
      String'Output (Stream, Request_Header);
      Write_Action (Stream, Action);
      Files.File_System.Drop_Import_Mode'Output (Stream, Mode);
      Write_String
        (Stream, Batch_Directory, Max_Transport_Path_Length);
   end Write_Request;

   procedure Read_Transport_Request
     (Path : String;
      Action : out Files.Paste.Resolved_Action;
      Mode : out Files.File_System.Drop_Import_Mode;
      Batch_Directory : out Files.Types.UString)
   is
      Input : aliased Files.Lease_Streams.Input_Stream;
   begin
      if Files.Lease_Streams.Open (Path, Input) /=
        Hostkit.Lease_Files.Opened
      then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      if Files.Bounded_Streams.Input_String
        (Input'Access, Request_Header'Length) /= Request_Header
      then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      Action := Read_Action (Input'Access);
      Mode := Files.File_System.Drop_Import_Mode'Input (Input'Access);
      Batch_Directory := To_Unbounded_String
        (Files.Bounded_Streams.Input_String
           (Input'Access, Max_Transport_Path_Length));
      if not Files.Lease_Streams.End_Of_Stream (Input)
        or else not Request_Is_Consistent
          (Action, To_String (Batch_Directory))
      then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      Files.Lease_Streams.Release (Input);
   exception
      when others =>
         Files.Lease_Streams.Release (Input);
         raise;
   end Read_Transport_Request;

   procedure Write_Result
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Result : Job_Result)
   is
   begin
      if not Result_Is_Consistent (Result) then
         raise Ada.Directories.Use_Error;
      end if;
      String'Output (Stream, Result_Header);
      Boolean'Output (Stream, Result.Mutation.Success);
      Write_String
        (Stream, To_String (Result.Mutation.Error_Key),
         Max_Transport_Error_Length);
      Boolean'Output (Stream, Result.Cancelled);
      Write_String
        (Stream, To_String (Result.Trashed), Max_Transport_Path_Length);
      Write_String
        (Stream, To_String (Result.Trashed_Identity),
         Max_Transport_Token_Length);
      Write_String
        (Stream, To_String (Result.Created_Identity),
         Max_Transport_Token_Length);
      Write_String
        (Stream, To_String (Result.Created_Tree_Revision),
         Max_Transport_Token_Length);
      Boolean'Output (Stream, Result.Recovered);
   end Write_Result;

   function Read_Transport_Result (Path : String) return Job_Result
   is
      Input : aliased Files.Lease_Streams.Input_Stream;
      Result : Job_Result;
   begin
      if Files.Lease_Streams.Open (Path, Input) /=
        Hostkit.Lease_Files.Opened
      then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      if Files.Bounded_Streams.Input_String
        (Input'Access, Result_Header'Length) /= Result_Header
      then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      Result.Mutation.Success := Boolean'Input (Input'Access);
      Result.Mutation.Error_Key := To_Unbounded_String
        (Files.Bounded_Streams.Input_String
           (Input'Access, Max_Transport_Error_Length));
      Result.Cancelled := Boolean'Input (Input'Access);
      Result.Trashed := To_Unbounded_String
        (Files.Bounded_Streams.Input_String
           (Input'Access, Max_Transport_Path_Length));
      Result.Trashed_Identity := To_Unbounded_String
        (Files.Bounded_Streams.Input_String
           (Input'Access, Max_Transport_Token_Length));
      Result.Created_Identity := To_Unbounded_String
        (Files.Bounded_Streams.Input_String
           (Input'Access, Max_Transport_Token_Length));
      Result.Created_Tree_Revision := To_Unbounded_String
        (Files.Bounded_Streams.Input_String
           (Input'Access, Max_Transport_Token_Length));
      Result.Recovered := Boolean'Input (Input'Access);
      if not Files.Lease_Streams.End_Of_Stream (Input)
        or else not Result_Is_Consistent (Result)
      then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      Files.Lease_Streams.Release (Input);
      return Result;
   exception
      when others =>
         Files.Lease_Streams.Release (Input);
         raise;
   end Read_Transport_Result;

   procedure Read_Replacement_Checkpoint
     (Path : String;
      Backup, Backup_Identity : out Files.Types.UString)
   is
      Input : aliased Files.Lease_Streams.Input_Stream;
   begin
      Backup := Null_Unbounded_String;
      Backup_Identity := Null_Unbounded_String;
      if Files.Lease_Streams.Open (Path, Input) /=
        Hostkit.Lease_Files.Opened
      then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      declare
         Decoded_Backup : constant String := Files.Bounded_Streams.Input_String
           (Input'Access, Max_Transport_Path_Length);
         Decoded_Identity : constant String := Files.Bounded_Streams.Input_String
           (Input'Access, Max_Transport_Token_Length);
      begin
         if not Files.Lease_Streams.End_Of_Stream (Input)
           or else not Valid_Absolute_Path (Decoded_Backup)
           or else Decoded_Identity = ""
           or else Files.File_Identities.Token (Decoded_Backup) /= Decoded_Identity
         then
            raise Ada.IO_Exceptions.Data_Error;
         end if;
         Backup := To_Unbounded_String (Decoded_Backup);
         Backup_Identity := To_Unbounded_String (Decoded_Identity);
      end;
      Files.Lease_Streams.Release (Input);
   exception
      when others =>
         Backup := Null_Unbounded_String;
         Backup_Identity := Null_Unbounded_String;
         Files.Lease_Streams.Release (Input);
         raise;
   end Read_Replacement_Checkpoint;

   function Is_Cancellation_Failure (Result : Job_Result) return Boolean is
     (not Result.Mutation.Success and then Length (Result.Trashed) = 0
      and then To_String (Result.Mutation.Error_Key) in "" | "error.drop.failed");

   procedure Start
     (Job    : in out Session;
      Action : Files.Paste.Resolved_Action;
      Mode   : Files.File_System.Drop_Import_Mode;
      Batch : Files.Copy_Context.Session := Files.Copy_Context.Empty_Session)
   is
      File : aliased Files.Exclusive_Streams.Output_Stream;
   begin
      Files.Process_Jobs.Reserve (Job.Process);
      Files.Exclusive_Streams.Create
        (File, Files.Process_Jobs.Path (Job.Process, "request"));
      Write_Request
        (File'Access, Action, Mode, Files.Copy_Context.Directory (Batch));
      Files.Exclusive_Streams.Close (File);
      Files.Process_Jobs.Launch (Job.Process, "--files-transfer");
   exception
      when others =>
         Files.Exclusive_Streams.Close_Safely (File);
         Reset (Job);
         raise;
   end Start;

   procedure Poll (Job : Session; Finished : out Boolean; Result : out Job_Result) is
      Cancelled : Boolean := False;

      procedure Recover is
         Action : Files.Paste.Resolved_Action;
         Mode : Files.File_System.Drop_Import_Mode;
         Destinations, Sources, Identities, Tree_Revisions : Files.Types.String_Vectors.Vector;
         Backup_Identity : Files.Types.UString;
         Batch_Directory : Files.Types.UString;
         use type Files.File_System.Drop_Import_Mode;
      begin
         begin
            Result := Read_Transport_Result
              (Files.Process_Jobs.Path (Job.Process, "completed"));
            Result.Recovered := True;
            Result.Cancelled := False;
            return;
         exception
            when Swallowed : others =>
               Files.Diagnostics.Note (Swallowed, "Files.Transfer_Jobs");
         end;
         Read_Transport_Request
           (Files.Process_Jobs.Path (Job.Process, "request"),
            Action, Mode, Batch_Directory);
         begin
            Read_Replacement_Checkpoint
              (Files.Process_Jobs.Path (Job.Process, "replaced"),
               Result.Trashed, Backup_Identity);
            Result.Trashed_Identity := Backup_Identity;
         exception
            when Swallowed : others =>
               Files.Diagnostics.Note (Swallowed, "Files.Transfer_Jobs");
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
         when Swallowed : others =>
            Files.Diagnostics.Note (Swallowed, "Files.Transfer_Jobs");
      end Recover;
   begin
      Result := (others => <>);
      Files.Process_Jobs.Poll (Job.Process, Finished, Cancelled);
      if Finished then
         Result := Read_Transport_Result
           (Files.Process_Jobs.Path (Job.Process, "result"));
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
      File   : aliased Files.Exclusive_Streams.Output_Stream;
      Action : Files.Paste.Resolved_Action;
      Mode   : Files.File_System.Drop_Import_Mode;
      Result : Job_Result;
      Plans  : Files.File_System.Drop_Import_Plan_Vectors.Vector;
      Identities, Tree_Revisions : Files.Types.String_Vectors.Vector;
      Preserved : Boolean := False;
      Batch : Files.Copy_Context.Session;
      Batch_Directory : Files.Types.UString;

      function Cancelled return Boolean is (Files.Process_Jobs.Cancellation_Requested (Directory));

      procedure Save is
         Output : aliased Files.Exclusive_Streams.Output_Stream;
      begin
         Files.Exclusive_Streams.Create
           (Output, Hostkit.Fs.Join (Directory, "result.tmp"));
         Write_Result (Output'Access, Result);
         Files.Exclusive_Streams.Close (Output);
         if not Files.Durable_Writes.Published
           (Files.Durable_Writes.Publish
              (Hostkit.Fs.Join (Directory, "result.tmp"), Hostkit.Fs.Join (Directory, "result")))
         then
            raise Ada.Directories.Use_Error;
         end if;
      exception
         when others =>
            Files.Exclusive_Streams.Close_Safely (Output);
            raise;
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
      Read_Transport_Request
        (Hostkit.Fs.Join (Directory, "request"),
         Action, Mode, Batch_Directory);
      if Length (Batch_Directory) > 0 then
         Batch := Files.Copy_Context.Borrow
           (To_String (Batch_Directory));
      end if;
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
                  if Hostkit.Fs.Is_Link (Hostkit.Fs.Join (Directory, "replaced.tmp"))
                    or else Ada.Directories.Exists (Hostkit.Fs.Join (Directory, "replaced.tmp"))
                    or else Hostkit.Fs.Is_Link (Hostkit.Fs.Join (Directory, "replaced"))
                    or else Ada.Directories.Exists (Hostkit.Fs.Join (Directory, "replaced"))
                  then
                     raise Ada.Directories.Use_Error;
                  end if;
                  Files.Exclusive_Streams.Create
                    (File, Hostkit.Fs.Join (Directory, "replaced.tmp"));
                  String'Output (File'Access, To_String (Result.Trashed));
                  String'Output
                    (File'Access, To_String (Result.Trashed_Identity));
                  Files.Exclusive_Streams.Close (File);
                  if not Files.Durable_Writes.Published
                    (Files.Durable_Writes.Publish
                       (Hostkit.Fs.Join (Directory, "replaced.tmp"),
                        Hostkit.Fs.Join (Directory, "replaced")))
                  then
                     raise Ada.Directories.Use_Error;
                  end if;
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
            Files.Exclusive_Streams.Create
              (File, Hostkit.Fs.Join (Directory, "completed.tmp"));
            Write_Result (File'Access, Result);
            Files.Exclusive_Streams.Close (File);
            declare
               Published : constant Files.Durable_Writes.Publication_Result := Files.Durable_Writes.Publish
                 (Hostkit.Fs.Join (Directory, "completed.tmp"), Hostkit.Fs.Join (Directory, "completed"));
               pragma Unreferenced (Published);
            begin
               null;
            end;
         exception
            when others =>
               Files.Exclusive_Streams.Close_Safely (File);
         end;
      end if;
      Save;
   end Run_Helper;
end Files.Transfer_Jobs;
