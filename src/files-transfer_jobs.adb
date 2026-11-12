with Files.Protocol_Names;
with Files.Job_Records;
with Files.Helper_Modes;
with Files.Diagnostics;
with Ada.Directories;
with Ada.IO_Exceptions;
with Ada.Streams;
with Ada.Strings.Unbounded;

with Files.Fs_Primitives;
with Hostkit.Fs;
with Files.Bounded_Streams;
with Files.Exclusive_Streams;
with Files.Durable_Writes;
with Files.Job_Context;
with Files.File_Identities;
with Files.Lease_Streams;
with Hostkit.Lease_Files;
with Files.Path_Checks;

package body Files.Transfer_Jobs is
   use Ada.Strings.Unbounded;
   use type Hostkit.Lease_Files.Open_Outcome;

   Max_Transport_Path_Length : constant := Files.Bounded_Streams.Max_Path_Length;
   Max_Transport_Token_Length : constant := Files.Bounded_Streams.Max_Token_Length;
   Max_Transport_Error_Length : constant := 256;
   Request_Header : constant String := "files-transfer-request-1";
   Result_Header : constant String := "files-transfer-result-1";

   function Valid_Absolute_Path (Path : String) return Boolean is
     (Files.Path_Checks.Valid_Absolute_Path (Path));

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
      Max_Length : Natural) renames Files.Bounded_Streams.Output_String;

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

   procedure Read_Result_Body
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Result : out Job_Result)
   is
      function Text (Maximum : Natural) return Files.Types.UString is
        (To_Unbounded_String (Files.Bounded_Streams.Input_String (Stream, Maximum)));
   begin
      Result.Mutation.Success := Boolean'Input (Stream);
      Result.Mutation.Error_Key := Text (Max_Transport_Error_Length);
      Result.Cancelled := Boolean'Input (Stream);
      Result.Trashed := Text (Max_Transport_Path_Length);
      Result.Trashed_Identity := Text (Max_Transport_Token_Length);
      Result.Created_Identity := Text (Max_Transport_Token_Length);
      Result.Created_Tree_Revision := Text (Max_Transport_Token_Length);
      Result.Recovered := Boolean'Input (Stream);
   end Read_Result_Body;

   function Read_Result_Record is new Files.Lease_Streams.Read_Record
     (Job_Result, Read_Result_Body, Result_Is_Consistent);

   function Read_Transport_Result (Path : String) return Job_Result is
     (Read_Result_Record (Path, Result_Header));

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

   procedure Apply_Replacement_Checkpoint
     (Path : String;
      Result : in out Job_Result)
   is
      Backup, Backup_Identity : Files.Types.UString;
   begin
      Read_Replacement_Checkpoint (Path, Backup, Backup_Identity);
      Result.Trashed := Backup;
      Result.Trashed_Identity := Backup_Identity;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Transfer_Jobs");
   end Apply_Replacement_Checkpoint;

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
        (File, Files.Process_Jobs.Path (Job.Process, Files.Process_Jobs.Request_File));
      Write_Request
        (File'Access, Action, Mode, Files.Copy_Context.Directory (Batch));
      Files.Exclusive_Streams.Close (File);
      Files.Process_Jobs.Launch (Job.Process, Files.Helper_Modes.Flag (Files.Helper_Modes.Transfer));
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
         Batch_Directory : Files.Types.UString;
         use type Files.File_System.Drop_Import_Mode;
      begin
         begin
            Result := Read_Transport_Result
              (Files.Process_Jobs.Path (Job.Process, Files.Protocol_Names.Completed_File));
            Result.Recovered := True;
            Result.Cancelled := False;
            return;
         exception
            when Swallowed : others =>
               Files.Diagnostics.Note (Swallowed, "Files.Transfer_Jobs");
         end;
         Read_Transport_Request
           (Files.Process_Jobs.Path (Job.Process, Files.Process_Jobs.Request_File),
            Action, Mode, Batch_Directory);
         Apply_Replacement_Checkpoint
           (Files.Process_Jobs.Path (Job.Process, Files.Protocol_Names.Replaced_File), Result);
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
      --  Set first: if Process_Jobs.Poll raises, the handler below reads it.
      Finished := False;
      Result := (others => <>);
      Files.Process_Jobs.Poll (Job.Process, Finished, Cancelled);
      if Finished then
         Result := Read_Transport_Result
           (Files.Process_Jobs.Path (Job.Process, Files.Process_Jobs.Result_File));
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
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Transfer_Jobs");
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
      Batch : Files.Copy_Context.Session;
      Batch_Directory : Files.Types.UString;

      function Cancelled return Boolean is (Files.Process_Jobs.Cancellation_Requested (Directory));

      procedure Save is
         procedure Write (Stream : not null access Ada.Streams.Root_Stream_Type'Class) is
         begin
            Write_Result (Stream, Result);
         end Write;
      begin
         Files.Job_Records.Publish_Result (Directory, Write'Access);
      end Save;

      --  The replaced original is held at Backup: retain it independently of
      --  result checkpoints before the import starts, so recovery finds it
      --  even if this helper dies mid-write.
      procedure Checkpoint (Backup, Backup_Identity : String) is
      begin
         Result.Trashed := To_Unbounded_String (Backup);
         Result.Trashed_Identity := To_Unbounded_String (Backup_Identity);
         if Hostkit.Fs.Is_Link (Hostkit.Fs.Join (Directory, Files.Protocol_Names.Staged_Replaced_File))
           or else Files.Fs_Primitives.Exists (Hostkit.Fs.Join (Directory, Files.Protocol_Names.Staged_Replaced_File))
           or else Hostkit.Fs.Is_Link (Hostkit.Fs.Join (Directory, Files.Protocol_Names.Replaced_File))
           or else Files.Fs_Primitives.Exists (Hostkit.Fs.Join (Directory, Files.Protocol_Names.Replaced_File))
         then
            raise Ada.Directories.Use_Error;
         end if;
         Files.Exclusive_Streams.Create
           (File, Hostkit.Fs.Join (Directory, Files.Protocol_Names.Staged_Replaced_File));
         String'Output (File'Access, Backup);
         String'Output (File'Access, Backup_Identity);
         Files.Exclusive_Streams.Close (File);
         if not Files.Durable_Writes.Published
           (Files.Durable_Writes.Publish
              (Hostkit.Fs.Join (Directory, Files.Protocol_Names.Staged_Replaced_File),
               Hostkit.Fs.Join (Directory, Files.Protocol_Names.Replaced_File)))
         then
            raise Ada.Directories.Use_Error;
         end if;
         Save;
      exception
         when others =>
            Files.Exclusive_Streams.Close_Safely (File);
            raise;
      end Checkpoint;

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
        (Hostkit.Fs.Join (Directory, Files.Process_Jobs.Request_File),
         Action, Mode, Batch_Directory);
      if Length (Batch_Directory) > 0 then
         Batch := Files.Copy_Context.Borrow
           (To_String (Batch_Directory));
      end if;
      Save;
      begin
         if Cancelled then
            Result.Cancelled := True;
         else
            --  A checkpoint represents unfinished work until the write completes.
            Result.Mutation := (Success => False, Error_Key => To_Unbounded_String ("error.drop.failed"));
            Save;
            declare
               Replaced, Replaced_Identity, Created_Identity, Created_Tree_Revision : Files.Types.UString;
               Mutation : constant Files.File_System.Mutation_Result :=
                 Files.File_System.Import_Replacing
                   (Source                => To_String (Action.Source_Path),
                    Destination           => To_String (Action.Dest_Path),
                    Mode                  => Mode,
                    Replace               => Action.Replaced,
                    Replaced              => Replaced,
                    Replaced_Identity     => Replaced_Identity,
                    Created_Identity      => Created_Identity,
                    Created_Tree_Revision => Created_Tree_Revision,
                    Preserved             => Checkpoint'Access,
                    Cancel                => Cancelled'Unrestricted_Access,
                    Batch                 => Batch);
            begin
               Result.Mutation := Mutation;
               Result.Trashed := Replaced;
               Result.Trashed_Identity := Replaced_Identity;
               Result.Created_Identity := Created_Identity;
               Result.Created_Tree_Revision := Created_Tree_Revision;
            end;
         end if;
      exception
         when Swallowed : others =>
            Files.Diagnostics.Note (Swallowed, "Files.Transfer_Jobs");
            Result.Mutation := (Success => False, Error_Key => To_Unbounded_String ("error.drop.failed"));
            Roll_Back;
      end;
      Result.Cancelled := Cancelled and then Is_Cancellation_Failure (Result);
      if Result.Mutation.Success then
         --  The result retains snapshots captured before publication even when
         --  the optional crash-recovery journal could not be extended.
         begin
            Files.Exclusive_Streams.Create
              (File, Hostkit.Fs.Join (Directory, Files.Protocol_Names.Staged_Completed_File));
            Write_Result (File'Access, Result);
            Files.Exclusive_Streams.Close (File);
            declare
               Published : constant Files.Durable_Writes.Publication_Result := Files.Durable_Writes.Publish
                 (Hostkit.Fs.Join (Directory, Files.Protocol_Names.Staged_Completed_File),
                  Hostkit.Fs.Join (Directory, Files.Protocol_Names.Completed_File));
               pragma Unreferenced (Published);
            begin
               null;
            end;
         exception
            when Swallowed : others =>
               Files.Diagnostics.Note (Swallowed, "Files.Transfer_Jobs");
               Files.Exclusive_Streams.Close_Safely (File);
         end;
      end if;
      Save;
   end Run_Helper;
end Files.Transfer_Jobs;
