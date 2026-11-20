with Files.Timing;
with Ada.Real_Time;
with Ada.Calendar;
with Ada.Directories;
with Ada.IO_Exceptions;
with Ada.Strings.Unbounded;
with Files.Diagnostics;
with Files.Durability;
with Files.Exclusive_Streams;
with Files.File_Identities;
with Files.Fs_Primitives;
with Files.Io_Errors;
with Hostkit.Fs;
with Hostkit.Metadata;

package body Files.Durable_Writes is
   use type Hostkit.Durability.Outcome;

   function Outcome_Of
     (File_Sync      : Hostkit.Durability.Outcome;
      Replaced       : Boolean;
      Directory_Sync : Hostkit.Durability.Outcome)
      return Publication_Result
   is
   begin
      if File_Sync /= Hostkit.Durability.Synced or else not Replaced then
         return Not_Published;
      elsif Directory_Sync = Hostkit.Durability.Failed then
         return Published_Not_Durable;
      else
         return Published_Durable;
      end if;
   end Outcome_Of;

   function Publish
     (Temporary, Target : String;
      Step              : out Publication_Step)
      return Publication_Result
   is
      File_Sync : Hostkit.Durability.Outcome;
      Replaced  : Boolean := False;
   begin
      Step := Raised;
      Files.Io_Errors.Clear_Os_Error;
      File_Sync := Files.Durability.Sync_File (Temporary);
      if File_Sync /= Hostkit.Durability.Synced then
         --  A full disk often shows only here, when the data is flushed.
         Files.Io_Errors.Capture;
         Step := File_Sync_Failed;
         return Not_Published;
      end if;
      Files.Io_Errors.Clear_Os_Error;
      Replaced := Hostkit.Fs.Replace_File (Temporary, Target);
      if not Replaced then
         Files.Io_Errors.Capture;
         Step := Replace_Failed;
         return Not_Published;
      end if;
      Step := Completed;
      return Outcome_Of
        (File_Sync,
         Replaced       => True,
         Directory_Sync => Files.Durability.Sync_Directory
           (Files.Fs_Primitives.Parent_Directory (Target)));
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Durable_Writes");
         return (if Replaced then Published_Not_Durable else Not_Published);
   end Publish;

   function Publish (Temporary, Target : String) return Publication_Result is
      Step : Publication_Step;
   begin
      return Publish (Temporary, Target, Step);
   end Publish;
   procedure Remove_Owned (Temporary : String; Identity : String) is
   begin
      if Identity /= "" and then Files.File_Identities.Token (Temporary) = Identity then
         Files.Fs_Primitives.Delete_File (Temporary);
      end if;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Durable_Writes");
   end Remove_Owned;

   --  Remove the file at Temporary that this unit just created exclusively,
   --  whose identity could not be read: the creation itself proved it ours.
   procedure Remove_Created (Temporary : String) is
   begin
      if not Hostkit.Fs.Delete_File (Temporary) then
         Files.Diagnostics.Trace ("Files.Durable_Writes", "own_temporary_kept=" & Temporary);
      end if;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Durable_Writes");
   end Remove_Created;

   procedure Write_Private_File
     (Temporary  : String;
      Write      : not null access procedure (Stream : not null access Ada.Streams.Root_Stream_Type'Class);
      Identity   : out Files.Types.UString;
      Name_Taken : out Boolean;
      Max_Bytes  : Long_Long_Integer := Long_Long_Integer'Last)
   is
      Output  : aliased Files.Exclusive_Streams.Output_Stream;
      Created : Boolean := False;
   begin
      Identity := Files.Types.UString'(Ada.Strings.Unbounded.Null_Unbounded_String);
      Name_Taken := False;
      Files.Io_Errors.Clear_Os_Error;
      begin
         Files.Exclusive_Streams.Create (Output, Temporary);
      exception
         when Ada.IO_Exceptions.Use_Error =>
            --  Asked after the failure, whose errno is already recorded.
            --  refusal-safe: a refused lookup is not a taken name, and the
            --  create's own failure is raised.
            if Files.Fs_Primitives.Entry_Exists (Temporary) then
               Name_Taken := True;
               return;
            end if;
            raise;
      end;
      Created := True;
      Identity := Ada.Strings.Unbounded.To_Unbounded_String (Files.File_Identities.Token (Temporary));
      if Ada.Strings.Unbounded.Length (Identity) = 0 then
         raise Ada.Directories.Use_Error;
      end if;
      Write (Output'Access);
      if Files.Exclusive_Streams.Size (Output) > Max_Bytes then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      Files.Exclusive_Streams.Close (Output);
      if Files.File_Identities.Token (Temporary) /= Ada.Strings.Unbounded.To_String (Identity) then
         raise Ada.Directories.Use_Error;
      end if;
   exception
      when others =>
         Files.Exclusive_Streams.Close_Safely (Output);
         if Created and then Ada.Strings.Unbounded.Length (Identity) = 0 then
            Remove_Created (Temporary);
         elsif Created then
            Remove_Owned (Temporary, Ada.Strings.Unbounded.To_String (Identity));
         end if;
         Identity := Ada.Strings.Unbounded.Null_Unbounded_String;
         raise;
   end Write_Private_File;

   procedure Write_Private_File
     (Temporary : String;
      Write     : not null access procedure (Stream : not null access Ada.Streams.Root_Stream_Type'Class);
      Identity  : out Files.Types.UString;
      Max_Bytes : Long_Long_Integer := Long_Long_Integer'Last)
   is
      Name_Taken : Boolean;
   begin
      Write_Private_File (Temporary, Write, Identity, Name_Taken, Max_Bytes);
      if Name_Taken then
         --  The create's own failure, recorded with Files.Io_Errors.
         raise Ada.Directories.Use_Error;
      end if;
   end Write_Private_File;

   procedure Write_Fixed_Private_File
     (Temporary : String;
      Write     : not null access procedure (Stream : not null access Ada.Streams.Root_Stream_Type'Class);
      Identity  : out Files.Types.UString;
      Max_Bytes : Long_Long_Integer := Long_Long_Integer'Last)
   is
   begin
      --  refusal-safe: a refused lookup leaves the name, and the write below fails
      if Files.Fs_Primitives.Entry_Exists (Temporary) then
         begin
            --  The write fails on this delete when it is refused: its reason
            --  is the operation's.
            Files.Fs_Primitives.Delete_File (Temporary, Record_Refusal => True);
         exception
            when Ada.Directories.Name_Error =>
               --  Gone meanwhile (a scanner that held it let go): the name
               --  is free, which is all the write needs.
               null;
         end;
      end if;
      Write_Private_File (Temporary, Write, Identity, Max_Bytes);
   end Write_Fixed_Private_File;

   --  When this process started, near enough: when this unit was elaborated.
   Process_Start : constant Ada.Calendar.Time := Ada.Calendar.Clock;
   --  The same moment on the monotonic clock. How long this process has run
   --  is the longer of the two clocks' answers (Run_Time).
   Process_Start_Monotonic : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;

   --  How long this process has run, on whichever clock says longer: the
   --  monotonic one does not count a suspend, and the wall clock can be set
   --  back. A run time too long only makes the start it gives earlier, and
   --  so fewer temporaries stale: the safe direction.
   function Run_Time return Duration is
     (Duration'Max
        (Files.Timing.Time_Since (Ada.Real_Time.Clock, Process_Start_Monotonic),
         Files.Timing.Time_Since (Ada.Calendar.Clock, Process_Start)));

   --  How much older than Process_Start a temporary must be to be stale.
   Stale_Margin : constant Duration := 60.0;

   --  When this process started, by the clock of the folder Base is in (a
   --  network share's server, say), not this machine's: a fresh temporary
   --  of Base's is written there and its modification time read, less the
   --  time this process has run (Run_Time). Found is False, and nothing may be judged
   --  stale, when that marker cannot be written or its time read (which
   --  raises inside, and is noted).
   procedure Folder_Process_Start
     (Base  : String;
      Start : out Ada.Calendar.Time;
      Found : out Boolean)
   is
      use type Ada.Calendar.Time;
      Marker, Identity : Files.Types.UString;

      procedure Write_Nothing (Stream : not null access Ada.Streams.Root_Stream_Type'Class) is null;
   begin
      Start := Process_Start;
      Found := False;
      --  Named as Base's temporaries are, so one a crash leaves behind is
      --  itself swept by a later sweep.
      Write_Private_Temporary (Base, Write_Nothing'Access, Marker, Identity);
      declare
         Path : constant String := Ada.Strings.Unbounded.To_String (Marker);
         Now  : constant Ada.Calendar.Time := Hostkit.Fs.Modification_Time_Of (Path, Follow_Links => False);
      begin
         Remove_Owned (Path, Ada.Strings.Unbounded.To_String (Identity));
         Start := Now - Run_Time;
         Found := True;
      end;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Durable_Writes");
         if Ada.Strings.Unbounded.Length (Marker) > 0 then
            Remove_Owned (Ada.Strings.Unbounded.To_String (Marker), Ada.Strings.Unbounded.To_String (Identity));
         end if;
         Found := False;
   end Folder_Process_Start;

   procedure Sweep_Stale_Temporaries (Base : String) is
      use type Ada.Calendar.Time;
      Directory : constant String := Files.Fs_Primitives.Parent_Directory (Base);
      Prefix    : constant String := Files.Types.Leaf_Of (Base) & ".tmp";
      Names     : Files.Types.String_Vectors.Vector;
      --  Process_Start by the folder's own clock (Folder_Process_Start).
      Start     : Ada.Calendar.Time;
      Found     : Boolean;

      --  Base & ".tmp", or Base & ".tmp-" and a number from 2.
      function Temporary_Name (Name : String) return Boolean is
        (Name = Prefix
         or else (Name'Length in Prefix'Length + 2 .. Prefix'Length + 5
                  and then Name (Name'First .. Name'First + Prefix'Length - 1) = Prefix
                  and then Name (Name'First + Prefix'Length) = '-'
                  and then Name (Name'First + Prefix'Length + 1) in '1' .. '9'
                  and then (for all C of Name (Name'First + Prefix'Length + 2 .. Name'Last) => C in '0' .. '9')));

      procedure Collect (Name : String; Stop : in out Boolean) is
      begin
         if Temporary_Name (Name) then
            Names.Append (Ada.Strings.Unbounded.To_Unbounded_String (Name));
         end if;
         Stop := Natural (Names.Length) >= 10_000;
      end Collect;

      procedure Remove_If_Stale (Path : String) is
         Identity : constant String := Files.File_Identities.Token (Path);
      begin
         --  Ours and private, by the host's own answer (mode bits and uid,
         --  or owner and access list): what Write_Private_File makes.
         if Identity /= ""
           and then not Hostkit.Fs.Is_Link (Path)
           and then Files.Fs_Primitives.File_Exists (Path)
           and then Hostkit.Metadata.Private_To_Current_User (Path)
           and then Hostkit.Fs.Modification_Time_Of (Path, Follow_Links => False) < Start - Stale_Margin
         then
            Remove_Owned (Path, Identity);
         end if;
      exception
         when Swallowed : others =>
            Files.Diagnostics.Note (Swallowed, "Files.Durable_Writes");
      end Remove_If_Stale;
   begin
      if Directory = "" then
         return;
      end if;
      Files.Fs_Primitives.For_Each_Name (Directory, Collect'Access);
      if Names.Is_Empty then
         return;
      end if;
      --  Judged by the folder's clock, which a share's server keeps and this
      --  machine's may be off from; without it, nothing is judged stale.
      Folder_Process_Start (Base, Start, Found);
      if not Found then
         Files.Diagnostics.Trace ("Files.Durable_Writes", "sweep_skipped_no_folder_time=" & Directory);
         return;
      end if;
      for Name of Names loop
         Remove_If_Stale (Hostkit.Fs.Join (Directory, Ada.Strings.Unbounded.To_String (Name)));
      end loop;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Durable_Writes");
   end Sweep_Stale_Temporaries;

   procedure Write_Private_Temporary
     (Base      : String;
      Write     : not null access procedure (Stream : not null access Ada.Streams.Root_Stream_Type'Class);
      Temporary : out Files.Types.UString;
      Identity  : out Files.Types.UString)
   is
      Max_Candidates : constant := 9_999;
   begin
      Temporary := Ada.Strings.Unbounded.Null_Unbounded_String;
      Identity := Ada.Strings.Unbounded.Null_Unbounded_String;
      for Index in 1 .. Max_Candidates loop
         declare
            Candidate : constant String :=
              Base & ".tmp" & (if Index = 1 then "" else "-" & Files.Types.Natural_Text (Index));
            Taken     : Boolean;
         begin
            --  Only a name already taken moves on to the next one; a refusal
            --  of any other kind (a full disk, no right to write there, a
            --  failure after the create) would refuse every name, and is
            --  raised. refusal-safe: a refused lookup is not a taken name
            --  (Write_Private_File), so it ends the search.
            Write_Private_File (Candidate, Write, Identity, Taken);
            if not Taken then
               Temporary := Ada.Strings.Unbounded.To_Unbounded_String (Candidate);
               return;
            end if;
         end;
      end loop;
      raise Ada.Directories.Use_Error with "no_free_temporary=" & Base;
   end Write_Private_Temporary;

   function Write_And_Publish
     (Target : String;
      Write  : not null access procedure (Stream : not null access Ada.Streams.Root_Stream_Type'Class))
      return Publication_Result
   is
      use Ada.Strings.Unbounded;
      Temporary, Identity : Files.Types.UString;
      Result : Publication_Result;
      Step   : Publication_Step;
      --  The code the caller had recorded, kept when the publish succeeds.
      Earlier : constant Integer := Files.Io_Errors.Last_Code;
   begin
      --  refusal-safe: a Target that cannot be looked at is neither absent
      --  nor a plain file, so it refuses the write.
      if Hostkit.Fs.Is_Link (Target)
        or else (not Files.Fs_Primitives.Entry_Is_Absent (Target)
          and then not Files.Fs_Primitives.File_Exists (Target))
      then
         raise Ada.Directories.Use_Error;
      end if;
      Write_Private_Temporary (Target, Write, Temporary, Identity);
      --  Start from no code, so the one traced below is this publish's own.
      Files.Io_Errors.Adopt_Code (0);
      Result := Publish (To_String (Temporary), Target, Step);
      if Published (Result) then
         --  Nothing failed: the caller's code stands.
         Files.Io_Errors.Adopt_Code (Earlier);
      else
         --  Why, for a host that refuses only now and then (a scanner holding
         --  the file just written shows as EBUSY, a refusal as EACCES): the
         --  code Publish recorded at the step that failed, or zero when that
         --  step gave none. Kept as the recorded code, never the caller's
         --  earlier one, which has nothing to do with this refusal.
         Files.Diagnostics.Trace
           ("Files.Durable_Writes",
            "publish_refused=" & Target & ",result=" & Result'Image & ",step=" & Step'Image
            & ",errno=" & Files.Io_Errors.Last_Code'Image);
         Remove_Owned (To_String (Temporary), To_String (Identity));
      end if;
      return Result;
   exception
      when others =>
         if Length (Temporary) > 0 then
            Remove_Owned (To_String (Temporary), To_String (Identity));
         end if;
         raise;
   end Write_And_Publish;

end Files.Durable_Writes;
