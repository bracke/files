with Files.Protocol_Names;
with Files.Jobs.Records;
with Files.Jobs.Helper_Modes;
with Files.Diagnostics;
with Ada.Directories;
with Ada.Strings.Unbounded;

with Files.IO.Fs_Primitives;
with Hostkit.Fs;
with Files.IO.Record_Fields;
with Files.Jobs.Context;
with Files.File_Identities;
with Files.IO.Lease_Streams;
with Files.Path_Checks;

package body Files.Transfer_Jobs is
   use Ada.Strings.Unbounded;

   Max_Transport_Path_Length : constant := Files.IO.Record_Fields.Max_Path_Length;
   Max_Transport_Token_Length : constant := Files.IO.Record_Fields.Max_Token_Length;
   Max_Transport_Error_Length : constant := 256;
   Request_Header : constant String := "files-transfer-request-1";
   Result_Header : constant String := "files-transfer-result-1";

   function Valid_Absolute_Path (Path : String; Max_Length : Natural := Natural'Last) return Boolean
     renames Files.Path_Checks.Valid_Absolute_Path;

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
             --  A failed move may still have kept its copy (see
             --  Files.File_System.Import_Replacing); a revision never comes
             --  without the identity it belongs to.
             (Has_Created_Identity or else not Has_Created_Revision)
             and then (not Result.Cancelled or else not Has_Trash));
   end Result_Is_Consistent;

   procedure Write_String
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Value : String;
      Max_Length : Natural) renames Files.IO.Record_Fields.Output_String;

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
        (Files.IO.Record_Fields.Input_String
           (Stream, Max_Transport_Path_Length));
      Result.Dest_Path := To_Unbounded_String
        (Files.IO.Record_Fields.Input_String
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

   type Transfer_Request is record
      Action          : Files.Paste.Resolved_Action;
      Mode            : Files.File_System.Drop_Import_Mode := Files.File_System.Drop_Copy;
      Batch_Directory : Files.Types.UString;
   end record;

   procedure Read_Request_Body
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Work   : out Transfer_Request) is
   begin
      Work.Action := Read_Action (Stream);
      Work.Mode := Files.File_System.Drop_Import_Mode'Input (Stream);
      Work.Batch_Directory :=
        To_Unbounded_String (Files.IO.Record_Fields.Input_String (Stream, Max_Transport_Path_Length));
   end Read_Request_Body;

   function Transfer_Request_Is_Consistent (Work : Transfer_Request) return Boolean is
     (Request_Is_Consistent (Work.Action, To_String (Work.Batch_Directory)));

   function Read_Request_Record is new Files.IO.Lease_Streams.Read_Record
     (Transfer_Request, Read_Request_Body, Transfer_Request_Is_Consistent);

   procedure Read_Transport_Request
     (Path : String;
      Action : out Files.Paste.Resolved_Action;
      Mode : out Files.File_System.Drop_Import_Mode;
      Batch_Directory : out Files.Types.UString)
   is
      Work : constant Transfer_Request := Read_Request_Record (Path, Request_Header);
   begin
      Action := Work.Action;
      Mode := Work.Mode;
      Batch_Directory := Work.Batch_Directory;
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
        (To_Unbounded_String (Files.IO.Record_Fields.Input_String (Stream, Maximum)));
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

   function Read_Result_Record is new Files.IO.Lease_Streams.Read_Record
     (Job_Result, Read_Result_Body, Result_Is_Consistent);

   function Read_Transport_Result (Path : String) return Job_Result is
     (Read_Result_Record (Path, Result_Header));

   procedure Write_Replacement_Checkpoint
     (Stream                  : not null access Ada.Streams.Root_Stream_Type'Class;
      Backup, Backup_Identity : String)
   is
   begin
      String'Output (Stream, Backup);
      String'Output (Stream, Backup_Identity);
   end Write_Replacement_Checkpoint;

   --  Where a replaced destination was set aside, and its identity.
   type Replacement_Checkpoint is record
      Backup          : Files.Types.UString;
      Backup_Identity : Files.Types.UString;
   end record;

   procedure Read_Checkpoint_Body
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Saved  : out Replacement_Checkpoint) is
   begin
      Saved.Backup := To_Unbounded_String (Files.IO.Record_Fields.Input_String (Stream, Max_Transport_Path_Length));
      Saved.Backup_Identity :=
        To_Unbounded_String (Files.IO.Record_Fields.Input_String (Stream, Max_Transport_Token_Length));
   end Read_Checkpoint_Body;

   function Checkpoint_Is_Consistent (Saved : Replacement_Checkpoint) return Boolean is
     (Valid_Absolute_Path (To_String (Saved.Backup))
      and then Length (Saved.Backup_Identity) > 0
      and then Files.File_Identities.Token (To_String (Saved.Backup)) = To_String (Saved.Backup_Identity));

   --  A checkpoint has no header: it is two strings.
   function Read_Checkpoint_Record is new Files.IO.Lease_Streams.Read_Record
     (Replacement_Checkpoint, Read_Checkpoint_Body, Checkpoint_Is_Consistent);

   procedure Read_Replacement_Checkpoint
     (Path : String;
      Backup, Backup_Identity : out Files.Types.UString)
   is
   begin
      Backup := Null_Unbounded_String;
      Backup_Identity := Null_Unbounded_String;
      declare
         Saved : constant Replacement_Checkpoint := Read_Checkpoint_Record (Path, Header => "");
      begin
         Backup := Saved.Backup;
         Backup_Identity := Saved.Backup_Identity;
      end;
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

   --  A failed result that is the cancel: its key, read as a finished job's,
   --  names no cause of its own (Files.File_System.Says_Only_Stopped), and
   --  no original is held.
   function Is_Cancellation_Failure (Result : Job_Result) return Boolean is
     (not Result.Mutation.Success and then Length (Result.Trashed) = 0
      and then Files.File_System.Says_Only_Stopped
        (To_String (Result.Mutation.Error_Key), Files.File_System.Finished_Job));

   procedure Start
     (Job    : in out Session;
      Action : Files.Paste.Resolved_Action;
      Mode   : Files.File_System.Drop_Import_Mode;
      Batch : Files.Jobs.Copy_Context.Session := Files.Jobs.Copy_Context.Empty_Session)
   is
      procedure Write (Stream : not null access Ada.Streams.Root_Stream_Type'Class) is
      begin
         Write_Request (Stream, Action, Mode, Files.Jobs.Copy_Context.Directory (Batch));
      end Write;
   begin
      Files.Jobs.Process.Reserve (Job);
      Files.Jobs.Process.Launch_With_Request (Job, Files.Jobs.Helper_Modes.Transfer, Write'Access);
   exception
      when others =>
         Reset (Job);
         raise;
   end Start;

   procedure Settle (Result : in out Job_Result; Cancelled : Boolean) is
   begin
      if Cancelled and then not Result.Mutation.Success then
         Result.Cancelled := Is_Cancellation_Failure (Result);
         if Length (Result.Trashed) > 0
           --  Read as a step's: a held original that a stop left held is
           --  what the user must learn, whatever stopped it.
           and then Files.File_System.Says_Only_Stopped
             (To_String (Result.Mutation.Error_Key), Files.File_System.Copy_Step)
         then
            Result.Mutation.Error_Key := To_Unbounded_String ("error.trash.restore_failed");
         end if;
      end if;
      --  A helper that failed without saying why -- it died between writing
      --  its first result and its last, or its last could not be published --
      --  still failed: an empty key read as success to the paste, which then
      --  stopped with the rest undone and nothing said.
      if not Result.Mutation.Success and then not Result.Cancelled
        and then Length (Result.Mutation.Error_Key) = 0
      then
         Result.Mutation.Error_Key := To_Unbounded_String ("error.drop.failed");
      end if;
   end Settle;

   procedure Poll (Job : Session; Finished : out Boolean; Result : out Job_Result) is
      Cancelled : Boolean := False;

      procedure Recover is
         Action : Files.Paste.Resolved_Action;
         Mode : Files.File_System.Drop_Import_Mode;
         Batch_Directory : Files.Types.UString;
         use type Files.File_System.Drop_Import_Mode;
      begin
         begin
            Result := Read_Transport_Result
              (Files.Jobs.Process.Path (Job, Files.Protocol_Names.Completed_File));
            Result.Recovered := True;
            Result.Cancelled := False;
            return;
         exception
            when Swallowed : others =>
               Files.Diagnostics.Note (Swallowed, "Files.Transfer_Jobs");
         end;
         Read_Transport_Request
           (Files.Jobs.Process.Path (Job, Files.Jobs.Process.Request_File),
            Action, Mode, Batch_Directory);
         Apply_Replacement_Checkpoint
           (Files.Jobs.Process.Path (Job, Files.Protocol_Names.Replaced_File), Result);
         declare
            Journal : constant Files.Jobs.Context.Journal_Entry_Vectors.Vector :=
              (if Mode = Files.File_System.Drop_Move
               then Files.Jobs.Context.Read_Moved (Files.Jobs.Process.Path (Job, ""))
               else Files.Jobs.Context.Read_Created (Files.Jobs.Process.Path (Job, "")));
         begin
            for Done of Journal loop
               if Done.Destination = Action.Dest_Path and then Done.Source = Action.Source_Path then
                  Result.Mutation := (Success => True, Error_Key => Null_Unbounded_String);
                  Result.Created_Identity := Done.Identity;
                  Result.Created_Tree_Revision := Done.Tree_Revision;
                  Result.Recovered := True;
                  Result.Cancelled := False;
               end if;
            end loop;
         end;
      exception
         when Swallowed : others =>
            Files.Diagnostics.Note (Swallowed, "Files.Transfer_Jobs");
      end Recover;
   begin
      --  Set first: if Jobs.Process.Poll raises, the handler below reads it.
      Finished := False;
      Result := (others => <>);
      Files.Jobs.Process.Poll (Job, Finished, Cancelled);
      if Finished then
         Result := Read_Transport_Result
           (Files.Jobs.Process.Path (Job, Files.Jobs.Process.Result_File));
         if not Result.Mutation.Success then
            Recover;
         end if;
         Settle (Result, Cancelled);
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
      Files.Jobs.Process.Cancel (Job);
   end Cancel;

   function Active (Job : Session) return Boolean is (Files.Jobs.Process.Active (Job));

   procedure Reset (Job : in out Session) is
   begin
      Files.Jobs.Process.Reset (Job);
   end Reset;

   procedure Run_Helper (Directory : String) is
      Action : Files.Paste.Resolved_Action;
      Mode   : Files.File_System.Drop_Import_Mode;
      Result : Job_Result;
      Batch : Files.Jobs.Copy_Context.Session;
      Batch_Directory : Files.Types.UString;

      --  The helper's one cancellation check. Import_Replacing is not handed
      --  it, but stops for the same marker through its default Cancel
      --  (Files.File_System.Job_Cancelled, which is this function).
      function Cancelled return Boolean renames Files.Jobs.Context.Cancelled;

      procedure Save is
         procedure Write (Stream : not null access Ada.Streams.Root_Stream_Type'Class) is
         begin
            Write_Result (Stream, Result);
         end Write;
      begin
         Files.Jobs.Records.Publish_Result (Directory, Write'Access);
      end Save;

      --  The replaced original is held at Backup: retain it independently of
      --  result checkpoints before the import starts, so recovery finds it
      --  even if this helper dies mid-write.
      procedure Checkpoint (Backup, Backup_Identity : String) is
         procedure Write (Stream : not null access Ada.Streams.Root_Stream_Type'Class) is
         begin
            Write_Replacement_Checkpoint (Stream, Backup, Backup_Identity);
         end Write;

         --  Whether anything, even a dangling link, holds Name in Directory.
         function Taken (Name : String) return Boolean is
           (not Files.IO.Fs_Primitives.Entry_Is_Absent (Hostkit.Fs.Join (Directory, Name)));
      begin
         Result.Trashed := To_Unbounded_String (Backup);
         Result.Trashed_Identity := To_Unbounded_String (Backup_Identity);
         --  One checkpoint per job: a second, or a stray staged copy, is refused.
         if Taken (Files.Jobs.Process.Staged_Name (Files.Protocol_Names.Replaced_File))
           or else Taken (Files.Protocol_Names.Replaced_File)
         then
            raise Ada.Directories.Use_Error;
         end if;
         Files.Jobs.Records.Publish_Result (Directory, Write'Access, Name => Files.Protocol_Names.Replaced_File);
         Save;
      end Checkpoint;

   begin
      Read_Transport_Request
        (Hostkit.Fs.Join (Directory, Files.Jobs.Process.Request_File),
         Action, Mode, Batch_Directory);
      if Length (Batch_Directory) > 0 then
         Batch := Files.Jobs.Copy_Context.Borrow
           (To_String (Batch_Directory));
      end if;
      Save;
      begin
         if Cancelled then
            Result.Cancelled := True;
         else
            --  A checkpoint represents unfinished work until the write completes.
            Result.Mutation :=
              (Success => False, Error_Key => To_Unbounded_String (Files.File_System.Interrupted_Error_Key));
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
            --  Import_Replacing rolls back its own failures; this covers only
            --  a raise around it, with the same routine. A kept copy holds
            --  the destination, so the original stays held.
            if Length (Result.Created_Identity) = 0 then
               Files.File_System.Put_Back_Replaced
                 (Result.Trashed, Result.Trashed_Identity, To_String (Action.Dest_Path), Result.Mutation);
            end if;
      end;
      Result.Cancelled := Cancelled and then Is_Cancellation_Failure (Result);
      if Result.Mutation.Success then
         --  The result retains snapshots captured before publication even when
         --  the optional crash-recovery journal could not be extended.
         declare
            procedure Write (Stream : not null access Ada.Streams.Root_Stream_Type'Class) is
            begin
               Write_Result (Stream, Result);
            end Write;
         begin
            Files.Jobs.Records.Publish_Result (Directory, Write'Access, Name => Files.Protocol_Names.Completed_File);
         exception
            when Swallowed : others =>
               Files.Diagnostics.Note (Swallowed, "Files.Transfer_Jobs");
         end;
      end if;
      Save;
   end Run_Helper;
end Files.Transfer_Jobs;
