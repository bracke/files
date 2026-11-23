with Ada.Directories;
with Ada.Streams;
with Ada.Strings.Unbounded;
with Files.Diagnostics;
with Files.File_System;
with Files.File_System_Types;
with Files.IO.Exclusive_Streams;
with Files.IO.Fs_Primitives;
with Files.IO.Lease_Streams;
with Files.IO.Record_Fields;
with Files.Jobs.Context;
with Files.Jobs.Helper_Modes;
with Files.Jobs.Records;
with Files.Path_Checks;
with Files.Protocol_Names;
with Hostkit.Fs;
with Hostkit.Watch;

package body Files.Refresh.Watch is
   use Ada.Strings.Unbounded;
   use type Ada.Directories.File_Kind;

   Max_Watch_Path_Length : constant := Files.IO.Record_Fields.Max_Path_Length;
   Watch_Request_Header : constant String := "files-watch-request-1";

   function Watch_Path_Is_Consistent (Path : String) return Boolean is
     (Path'Length <= Max_Watch_Path_Length
      and then Files.Path_Checks.Valid_Absolute_Path (Path));

   function Watch_Refresh_Due
     (Pacer   : in out Watch_Pacer;
      Now     : Ada.Real_Time.Time;
      Changed : Boolean) return Boolean
   is
      use type Ada.Real_Time.Time;
   begin
      Pacer.Owed := Pacer.Owed or else Changed;
      if not Pacer.Owed
        or else (Pacer.Refreshed and then Now < Pacer.Last_Refresh + Watch_Refresh_Gap)
      then
         return False;
      end if;
      Pacer.Owed := False;
      Pacer.Refreshed := True;
      Pacer.Last_Refresh := Now;
      return True;
   end Watch_Refresh_Due;

   procedure Owe_Watch_Refresh (Pacer : in out Watch_Pacer; Changed : Boolean) is
   begin
      Pacer.Owed := Pacer.Owed or else Changed;
   end Owe_Watch_Refresh;

   function Retry_Due
     (Pacer       : in out Watch_Pacer;
      Now         : Ada.Real_Time.Time;
      Load_Failed : Boolean) return Boolean
   is
      use type Ada.Real_Time.Time;
   begin
      if not Load_Failed then
         Pacer.Retry_At := Ada.Real_Time.Time_First;
         return True;
      elsif Now < Pacer.Retry_At then
         return False;
      end if;
      Pacer.Retry_At := Now + Load_Retry_Gap;
      return True;
   end Retry_Due;

   function Watch_Step
     (Pacer       : in out Watch_Pacer;
      Now         : Ada.Real_Time.Time;
      Changed     : Boolean;
      Read_Active : Boolean;
      Load_Failed : Boolean;
      Poll_Due    : Boolean;
      Polled      : out Boolean) return Watch_Step_Action is
   begin
      Polled := False;
      --  While a read runs nothing is started, so nothing is paid: the
      --  change stays owed until the read is in.
      if Read_Active then
         Owe_Watch_Refresh (Pacer, Changed);
         return Watch_Wait;
      elsif Watch_Refresh_Due (Pacer, Now, Changed) then
         return (if Retry_Due (Pacer, Now, Load_Failed) then Watch_Refresh else Watch_Wait);
      elsif Changed or else not Poll_Due then
         return Watch_Wait;
      end if;
      Polled := True;
      return (if Retry_Due (Pacer, Now, Load_Failed) then Watch_Refresh else Watch_Wait);
   end Watch_Step;

   procedure Release_Watch (Job : in out Watch_Session) is
   begin
      Files.Jobs.Process.Reset (Job.Process);
      Job.Path := Null_Unbounded_String;
      Job.Claim_Left := False;
      Job.Native := False;
   end Release_Watch;

   function Watch_Is_Native (Job : in out Watch_Session) return Boolean is
   begin
      if not Job.Native and then Files.Jobs.Process.Active (Job.Process) then
         Job.Native :=
           --  refusal-safe: a marker not seen keeps the polling fallback on,
           --  which only costs polls; it is asked again next pass.
           Files.IO.Fs_Primitives.Exists
             (Files.Jobs.Process.Path (Job.Process, Files.Protocol_Names.Native_Watch_File));
      end if;
      return Job.Native and then Files.Jobs.Process.Active (Job.Process);
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Refresh.Watch");
         return False;
   end Watch_Is_Native;

   Watch_Retry_Delay : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Seconds (5);

   procedure Watch_Path (Job : in out Watch_Session; Path : String) is
      use type Ada.Real_Time.Time;

      procedure Write (Stream : not null access Ada.Streams.Root_Stream_Type'Class) is
      begin
         String'Output (Stream, Watch_Request_Header);
         Files.IO.Record_Fields.Output_String (Stream, Path, Max_Watch_Path_Length);
      end Write;

      procedure Note_Failure is
      begin
         Job.Failed_Path := To_Unbounded_String (Path);
         Job.Retry_At := Ada.Real_Time.Clock + Watch_Retry_Delay;
      end Note_Failure;
   begin
      if Job.Path = Path then
         return;
      end if;
      Release_Watch (Job);
      if Path = "" then
         return;
      end if;
      --  The window calls this every loop pass. Without a back-off, a helper
      --  that cannot start (or exits at once, e.g. mid package upgrade) was
      --  relaunched, with a fresh transport and fsyncs, on every pass.
      if Job.Failed_Path = Path and then Ada.Real_Time.Clock < Job.Retry_At then
         return;
      end if;
      if not Watch_Path_Is_Consistent (Path) then
         --  The helper cannot decode this request. Leave the session inactive
         --  so the caller uses its polling fallback instead of repeatedly
         --  launching a helper that exits immediately.
         return;
      end if;
      Files.Jobs.Process.Reserve (Job.Process);
      Files.Jobs.Process.Launch_With_Request (Job.Process, Files.Jobs.Helper_Modes.Watch, Write'Access);
      Job.Path := To_Unbounded_String (Path);
   exception
      when Failure : others =>
         Files.Diagnostics.Note (Failure, "Files.Refresh.Watch");
         Release_Watch (Job);
         Note_Failure;
   end Watch_Path;

   function Claim_Watch_Notification (Directory : String) return Boolean is
     (Hostkit.Fs.Move_No_Replace
        (Hostkit.Fs.Join (Directory, Files.Protocol_Names.Changed_File),
         Hostkit.Fs.Join (Directory, Files.Protocol_Names.Claimed_Changed_File)));

   function Post_Watch_Notification (Directory : String) return Boolean is
      File   : Files.IO.Exclusive_Streams.Output_Stream;
      Target : constant String := Hostkit.Fs.Join (Directory, Files.Protocol_Names.Changed_File);

      --  refusal-safe: a marker not seen is made exclusively, which cannot
      --  write over one; a hint lost is given again by the next poll.
      function Posted return Boolean is
        (not Hostkit.Fs.Is_Link (Target)
         --  refusal-safe: as above.
         and then Files.IO.Fs_Primitives.Exists (Target)
         and then Files.IO.Fs_Primitives.Kind (Target) = Ada.Directories.Ordinary_File);
   begin
      --  One unread marker says it all: the window re-reads the folder, not
      --  the events. And it is made in place, with no sync: it carries no
      --  data, and a crash loses only a hint the next poll gives again. As a
      --  durable publish it cost two fsyncs per event under steady writes.
      if Posted then
         return True;
      end if;
      Files.IO.Exclusive_Streams.Create (File, Target);
      Files.IO.Exclusive_Streams.Close (File);
      return True;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Refresh.Watch");
         Files.IO.Exclusive_Streams.Close_Safely (File);
         --  Made meanwhile by nobody else, but answer by what is there.
         return Posted;
   end Post_Watch_Notification;

   function Poll_Watch (Job : in out Watch_Session) return Boolean is
      Finished, Cancelled : Boolean;
      Directory : constant String := Files.Jobs.Process.Path (Job.Process, "");
      Claimed : constant String := Hostkit.Fs.Join (Directory, Files.Protocol_Names.Claimed_Changed_File);

      procedure Remove_Claim is
      begin
         if Hostkit.Fs.Is_Link (Claimed) then
            declare
               Removed : constant Boolean := Hostkit.Fs.Delete_Link (Claimed);
               pragma Unreferenced (Removed);
            begin
               null;
            end;
         elsif Files.IO.Fs_Primitives.Entry_Is_Absent (Claimed) then
            null;
         elsif Files.IO.Fs_Primitives.Kind (Claimed) = Ada.Directories.Ordinary_File then
            --  A claim that cannot be looked at raises above (Kind) and
            --  stays to be removed, not taken for gone: left, it would
            --  refuse every later claim of a change.
            Files.IO.Fs_Primitives.Delete_File (Claimed);
         end if;
         Job.Claim_Left := False;
      exception
         when Swallowed : others =>
            Job.Claim_Left := True;
            Files.Diagnostics.Note (Swallowed, "Files.Refresh.Watch");
      end Remove_Claim;
   begin
      if not Files.Jobs.Process.Active (Job.Process) then
         return False;
      end if;
      Files.Jobs.Process.Poll (Job.Process, Finished, Cancelled);
      if Finished then
         --  A watch helper runs until released; finishing on its own means it
         --  failed, so hold off relaunching it for this path (see Watch_Path).
         Job.Failed_Path := Job.Path;
         Job.Retry_At := Ada.Real_Time."+" (Ada.Real_Time.Clock, Watch_Retry_Delay);
         Release_Watch (Job);
         return False;
      end if;
      --  Clear an acknowledgement left by a transient unlink failure, then
      --  atomically claim the current marker.  A marker published after this
      --  rename remains at "changed" for the next poll.
      if Job.Claim_Left then
         Remove_Claim;
      end if;
      if Claim_Watch_Notification (Directory) then
         Remove_Claim;
         return True;
      end if;
      return False;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Refresh.Watch");
         return False;
   end Poll_Watch;

   procedure Read_Watch_Body
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Path   : out Unbounded_String) is
   begin
      Path := To_Unbounded_String (Files.IO.Record_Fields.Input_String (Stream, Max_Watch_Path_Length));
   end Read_Watch_Body;

   function Watch_Request_Is_Consistent (Path : Unbounded_String) return Boolean is
     (Watch_Path_Is_Consistent (To_String (Path)));

   function Read_Watch_Record is new Files.IO.Lease_Streams.Read_Record
     (Unbounded_String, Read_Watch_Body, Watch_Request_Is_Consistent);

   function Read_Watch_Request (Path : String) return Unbounded_String is
     (Read_Watch_Record (Path, Watch_Request_Header, Long_Long_Integer (Files.Jobs.Records.Max_Transport_Bytes)));

   procedure Run_Watch_Helper (Directory : String) is
      use type Ada.Real_Time.Time;
      use type Ada.Real_Time.Time_Span;
      Watch : Hostkit.Watch.Watch_State;
      Pending : Boolean := False;
      Watched : Unbounded_String;
      --  Where the watch does not hear a file being written (macOS, Windows,
      --  a filesystem with no notifications), this helper re-reads the
      --  folder's signature itself and posts a change when it moved: one stat
      --  per entry here, instead of the window starting a helper, a
      --  transport and four fsyncs for every timed re-read.
      Polls_Itself : Boolean := False;
      Last_State   : Files.File_System_Types.Directory_Signature;
      Next_Scan    : Ada.Real_Time.Time := Ada.Real_Time.Time_First;

      --  A second, and a second more per 20,000 entries.
      function Scan_Gap (Entries : Natural) return Ada.Real_Time.Time_Span is
        (Ada.Real_Time.Seconds (1) + Ada.Real_Time.Milliseconds (Natural'Min (Entries, 1_000_000) / 20));
   begin
      Watched := Read_Watch_Request (Hostkit.Fs.Join (Directory, Files.Jobs.Process.Request_File));
      Hostkit.Watch.Watch_Path (Watch, To_String (Watched));
      Polls_Itself := not (Hostkit.Watch.Is_Active (Watch) and then Hostkit.Watch.Sees_File_Writes);
      if Polls_Itself then
         Last_State := Files.File_System.Directory_State (To_String (Watched));
         Next_Scan := Ada.Real_Time.Clock + Scan_Gap (Last_State.Entry_Count);
      end if;
      --  Tell the window its timed re-read can relax (Watch_Is_Native): this
      --  helper reports what the listing shows, file growth included, either
      --  from the watch or from its own re-reads.
      declare
         Marker : Files.IO.Exclusive_Streams.Output_Stream;
      begin
         Files.IO.Exclusive_Streams.Create
           (Marker, Hostkit.Fs.Join (Directory, Files.Protocol_Names.Native_Watch_File));
         Files.IO.Exclusive_Streams.Close (Marker);
      exception
         when Swallowed : others =>
            Files.IO.Exclusive_Streams.Close_Safely (Marker);
            Files.Diagnostics.Note (Swallowed, "Files.Refresh.Watch");
      end;
      loop
         exit when Files.Jobs.Context.Cancelled;
         if Hostkit.Watch.Poll (Watch) then
            Pending := True;
         end if;
         if Polls_Itself and then Ada.Real_Time.Clock >= Next_Scan then
            declare
               State : constant Files.File_System_Types.Directory_Signature :=
                 Files.File_System.Directory_State (To_String (Watched));
            begin
               --  Moved, or became readable or unreadable; a folder that
               --  stays unreadable (no state either time) is not a change.
               if (State.Taken or else Last_State.Taken)
                 and then not Files.File_System_Types.Same_State (State, Last_State)
               then
                  Pending := True;
                  Last_State := State;
               end if;
               Next_Scan := Ada.Real_Time.Clock + Scan_Gap (State.Entry_Count);
            end;
         end if;
         if Pending and then Post_Watch_Notification (Directory) then
            Pending := False;
         end if;
         delay 0.05;
      end loop;
      Hostkit.Watch.Release (Watch);
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Refresh.Watch");
         Hostkit.Watch.Release (Watch);
   end Run_Watch_Helper;

end Files.Refresh.Watch;
