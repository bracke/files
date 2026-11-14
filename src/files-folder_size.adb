with Files.Diagnostics;
with Files.Helper_Modes;
with Ada.Directories;
with Ada.Containers.Hashed_Maps;
with Ada.IO_Exceptions;
with Ada.Streams;
with Ada.Strings.Unbounded.Hash;
with Files.Bounded_Streams;
with Files.Job_Context;
with Files.Job_Records;
with Files.Lease_Streams;
with Files.Fs_Primitives;
with Hostkit.Fs;
with Files.Path_Checks;

package body Files.Folder_Size is
   use Ada.Strings.Unbounded;

   Max_Request_Path_Length : constant := Files.Bounded_Streams.Max_Path_Length;
   Max_Record_Bytes : constant := 64 * 1024;
   --  A batch request: up to Max_Batch paths, within this many bytes.
   Max_Request_Bytes : constant := 1024 * 1024;
   Request_Header : constant String := "files-folder-size-request-2";
   Result_Header : constant String := "files-folder-size-result-1";

   function Request_Path_Is_Valid (Path : String) return Boolean is
     (Files.Path_Checks.Valid_Absolute_Path (Path, Max_Request_Path_Length));

   procedure Write_Request
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Paths  : Path_Vectors.Vector)
   is
   begin
      if Paths.Is_Empty or else Natural (Paths.Length) > Max_Batch then
         raise Ada.Directories.Use_Error;
      end if;
      String'Output (Stream, Request_Header);
      Natural'Output (Stream, Natural (Paths.Length));
      for Path of Paths loop
         if not Request_Path_Is_Valid (To_String (Path)) then
            raise Ada.Directories.Use_Error;
         end if;
         String'Output (Stream, To_String (Path));
      end loop;
   end Write_Request;

   procedure Read_Request_Body
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Paths  : out Path_Vectors.Vector)
   is
      Count : constant Natural := Natural'Input (Stream);
   begin
      if Count not in 1 .. Max_Batch then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      for Index in 1 .. Count loop
         Paths.Append (To_Unbounded_String (Files.Bounded_Streams.Input_String (Stream, Max_Request_Path_Length)));
      end loop;
   end Read_Request_Body;

   function Request_Is_Consistent (Paths : Path_Vectors.Vector) return Boolean is
     (for all Path of Paths => Request_Path_Is_Valid (To_String (Path)));

   function Read_Request_Record is new Files.Lease_Streams.Read_Record
     (Path_Vectors.Vector, Read_Request_Body, Request_Is_Consistent);

   function Read_Request (Path : String) return Path_Vectors.Vector is
     (Read_Request_Record (Path, Request_Header, Long_Long_Integer (Max_Request_Bytes)));

   --  The helper publishes the Index-th result under this name once written.
   function Result_Name (Index : Positive) return String is
     ("result-" & Files.Types.Natural_Text (Index));

   --  What Write_Result refuses to write.
   function Result_Is_Consistent (Result : Files.File_System.Directory_Size_Result) return Boolean is
     (Result.Total_Bytes >= 0
      and then Result.File_Count <= Result.Item_Count
      and then
        (Result.Available
         or else
           (Result.Total_Bytes = 0
            and then Result.File_Count = 0
            and then Result.Item_Count = 0
            and then not Result.Capped)));

   procedure Write_Result
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Result : Files.File_System.Directory_Size_Result)
   is
   begin
      if not Result_Is_Consistent (Result) then
         raise Ada.Directories.Use_Error;
      end if;
      String'Output (Stream, Result_Header);
      Boolean'Output (Stream, Result.Available);
      Long_Long_Integer'Output (Stream, Result.Total_Bytes);
      Natural'Output (Stream, Result.File_Count);
      Natural'Output (Stream, Result.Item_Count);
      Boolean'Output (Stream, Result.Capped);
   end Write_Result;

   procedure Read_Result_Body
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Result : out Files.File_System.Directory_Size_Result) is
   begin
      Result.Available := Boolean'Input (Stream);
      Result.Total_Bytes := Long_Long_Integer'Input (Stream);
      Result.File_Count := Natural'Input (Stream);
      Result.Item_Count := Natural'Input (Stream);
      Result.Capped := Boolean'Input (Stream);
   end Read_Result_Body;

   function Read_Result_Record is new Files.Lease_Streams.Read_Record
     (Files.File_System.Directory_Size_Result, Read_Result_Body, Result_Is_Consistent);

   function Read_Result
     (Path : String)
      return Files.File_System.Directory_Size_Result is
     (Read_Result_Record (Path, Result_Header, Long_Long_Integer (Max_Record_Bytes)));

   --  Whether a finished measurement of Path, asked for as listed at Listed,
   --  waits to be handed over: one of an older listing does not count.
   function Is_Queued (Scan : Session; Path : Unbounded_String; Listed : Ada.Calendar.Time) return Boolean is
     (for some Done of Scan.Done_Queue => Done.Path = Path and then Ada.Calendar."=" (Done.Listed, Listed));

   --  The batch's Index-th directory answered: Result, as asked for.
   function Answer
     (Scan   : Session;
      Index  : Positive;
      Result : Files.File_System.Directory_Size_Result) return Measurement is
     ((Path => Scan.Batch (Index).Path, Result => Result, Listed => Scan.Batch (Index).Listed));

   procedure Start_Next (Scan : in out Session) is
      Bytes : Natural := 0;
      Paths : Path_Vectors.Vector;

      procedure Write (Stream : not null access Ada.Streams.Root_Stream_Type'Class) is
      begin
         Write_Request (Stream, Paths);
      end Write;
   begin
      Scan.Batch.Clear;
      Scan.Next_Result := 1;
      Scan.Read_Retries := 0;
      --  As many as fit one request.
      while not Scan.Targets.Is_Empty
        and then Natural (Scan.Batch.Length) < Max_Batch
        and then Bytes + Length (Scan.Targets.First_Element.Path) + 64 <= Max_Request_Bytes
      loop
         Bytes := Bytes + Length (Scan.Targets.First_Element.Path) + 64;
         Scan.Batch.Append (Scan.Targets.First_Element);
         Paths.Append (Scan.Targets.First_Element.Path);
         Scan.Targets.Delete_First;
      end loop;
      if Scan.Batch.Is_Empty then
         return;
      end if;
      Files.Process_Jobs.Reserve (Scan.Job);
      Files.Process_Jobs.Launch_With_Request (Scan.Job, Files.Helper_Modes.Folder_Size, Write'Access);
      Test_Helper_Starts := (if Test_Helper_Starts = Natural'Last then 0 else Test_Helper_Starts + 1);
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Folder_Size");
         Files.Process_Jobs.Reset (Scan.Job);
         --  Every directory of the batch is answered, unmeasured.
         for Index in 1 .. Natural (Scan.Batch.Length) loop
            Scan.Done_Queue.Append (Answer (Scan, Index, (others => <>)));
         end loop;
         Scan.Batch.Clear;
   end Start_Next;

   procedure Set_Targets (Scan : in out Session; Targets : Target_Vectors.Vector) is
      package Time_Maps is new Ada.Containers.Hashed_Maps
        (Key_Type        => Unbounded_String,
         Element_Type    => Ada.Calendar.Time,
         Hash            => Ada.Strings.Unbounded.Hash,
         Equivalent_Keys => Ada.Strings.Unbounded."=",
         "="             => Ada.Calendar."=");
      --  Each wanted directory, and when it was listed.
      Requested : Time_Maps.Map;
      Keep      : Boolean;
   begin
      for Wanted of Targets loop
         if Request_Path_Is_Valid (To_String (Wanted.Path)) then
            Requested.Include (Wanted.Path, Wanted.Listed);
         end if;
      end loop;
      --  The running helper is kept while it has directories left to report
      --  and every one of them is still wanted, as listed when it was asked
      --  for; those are not asked again.
      Keep := Files.Process_Jobs.Active (Scan.Job)
        and then Scan.Next_Result <= Natural (Scan.Batch.Length)
        and then (for all Index in Scan.Next_Result .. Natural (Scan.Batch.Length) =>
                    Requested.Contains (Scan.Batch (Index).Path)
                    and then Ada.Calendar."="
                      (Requested.Element (Scan.Batch (Index).Path), Scan.Batch (Index).Listed));
      if Keep then
         for Index in Scan.Next_Result .. Natural (Scan.Batch.Length) loop
            Requested.Exclude (Scan.Batch (Index).Path);
         end loop;
      end if;
      Scan.Targets.Clear;
      for Wanted of Targets loop
         if Requested.Contains (Wanted.Path)
           and then not Is_Queued (Scan, Wanted.Path, Requested.Element (Wanted.Path))
         then
            Scan.Targets.Append (Target'(Path => Wanted.Path, Listed => Requested.Element (Wanted.Path)));
            Requested.Delete (Wanted.Path);
         end if;
      end loop;
      if not Keep then
         Files.Process_Jobs.Reset (Scan.Job);
         Start_Next (Scan);
      end if;
   end Set_Targets;

   procedure Set_Targets (Scan : in out Session; Paths : Path_Vectors.Vector) is
      Targets : Target_Vectors.Vector;
   begin
      for Path of Paths loop
         Targets.Append (Target'(Path => Path, Listed => Files.Types.Unknown_Time));
      end loop;
      Set_Targets (Scan, Targets);
   end Set_Targets;

   procedure Measure_Again (Scan : in out Session; Path : String; Listed : Ada.Calendar.Time) is
      Item : constant Unbounded_String := To_Unbounded_String (Path);
   begin
      if not Request_Path_Is_Valid (Path)
        or else Is_Queued (Scan, Item, Listed)
        or else (for some Wanted of Scan.Targets => Wanted.Path = Item)
        or else (for some Index in Scan.Next_Result .. Natural (Scan.Batch.Length) =>
                   Scan.Batch (Index).Path = Item
                   and then Ada.Calendar."=" (Scan.Batch (Index).Listed, Listed))
      then
         return;
      end if;
      --  Behind the targets: Step starts it once the running helper stops.
      Scan.Targets.Append (Target'(Path => Item, Listed => Listed));
   end Measure_Again;

   procedure Cancel (Scan : in out Session) is
   begin
      Scan.Set_For_Rows := Natural'Last;
      Scan.Set_For_Selection := Natural'Last;
      Files.Process_Jobs.Reset (Scan.Job);
      Scan.Targets.Clear;
      Scan.Batch.Clear;
      Scan.Next_Result := 1;
      Scan.Read_Retries := 0;
   end Cancel;

   --  Take the helper's published results, in order. A result that is there
   --  but will not open yet (on Windows, a file just renamed into place can
   --  refuse its lease for a moment: CI saw this answer a folder as
   --  unmeasured) is read again on a later step: while the helper runs, for
   --  as long as it takes; once it has Finished, on Finished_Read_Retries
   --  more steps, and then it is answered unmeasured. Nothing here waits.
   --
   --  @param Waiting Set True when a finished helper's result is to be read
   --    again on a later step.
   procedure Collect (Scan : in out Session; Finished : Boolean; Waiting : out Boolean) is
   begin
      Waiting := False;
      while Scan.Next_Result <= Natural (Scan.Batch.Length) loop
         declare
            Name : constant String :=
              Files.Process_Jobs.Path (Scan.Job, Result_Name (Scan.Next_Result));
            Result : Files.File_System.Directory_Size_Result;
            Read   : Boolean := False;
         begin
            exit when not Files.Fs_Primitives.Exists (Name);
            begin
               if Test_Unreadable_Results > 0 then
                  Test_Unreadable_Results := Test_Unreadable_Results - 1;
                  raise Ada.Directories.Use_Error;
               end if;
               Result := Read_Result (Name);
               Read := True;
            exception
               when Swallowed : others =>
                  Files.Diagnostics.Note (Swallowed, "Files.Folder_Size");
            end;
            if not Read then
               exit when not Finished;
               if Scan.Read_Retries < Finished_Read_Retries then
                  Scan.Read_Retries := Scan.Read_Retries + 1;
                  Waiting := True;
                  exit;
               end if;
               Result := (others => <>);
            end if;
            Scan.Read_Retries := 0;
            Scan.Done_Queue.Append (Answer (Scan, Scan.Next_Result, Result));
            Scan.Next_Result := Scan.Next_Result + 1;
         end;
      end loop;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Folder_Size");
   end Collect;

   procedure Step (Scan : in out Session) is
      Finished, Waiting : Boolean;
      --  Poll's cancelled state, which a scan has no use for (below).
      Discarded_Cancelled : Boolean;
   begin
      if not Files.Process_Jobs.Active (Scan.Job) then
         --  A batch whose helper could not start was answered unmeasured;
         --  the directories after it still wait for one. A launch that keeps
         --  failing answers a batch per step, so they all get an answer.
         if not Scan.Targets.Is_Empty then
            Start_Next (Scan);
         end if;
         return;
      end if;
      --  A scan is stopped by Reset (Cancel), never by Process_Jobs.Cancel, so
      --  the cancelled state carries nothing here: a finished helper is
      --  collected and the next batch started either way.
      Files.Process_Jobs.Poll (Scan.Job, Finished, Discarded_Cancelled);
      Collect (Scan, Finished, Waiting);
      if not Finished or else Waiting then
         return;
      end if;
      --  What a helper that stopped early did not measure is answered,
      --  unmeasured, so the window does not wait for it.
      for Index in Scan.Next_Result .. Natural (Scan.Batch.Length) loop
         Scan.Done_Queue.Append (Answer (Scan, Index, (others => <>)));
      end loop;
      Files.Process_Jobs.Reset (Scan.Job);
      Start_Next (Scan);
   end Step;

   procedure Take_All (Scan : in out Session; Taken : out Measurement_Vectors.Vector) is
   begin
      Taken.Move (Scan.Done_Queue);
   end Take_All;

   procedure Take_Due
     (Scan  : in out Session;
      Now   : Ada.Real_Time.Time;
      Taken : out Measurement_Vectors.Vector)
   is
      use type Ada.Real_Time.Time;
      Working : constant Boolean := Files.Process_Jobs.Active (Scan.Job) or else not Scan.Targets.Is_Empty;
   begin
      Taken.Clear;
      if Scan.Done_Queue.Is_Empty
        or else (Working and then Now < Scan.Handed_At + Hand_Over_Interval)
      then
         return;
      end if;
      Taken.Move (Scan.Done_Queue);
      Scan.Handed_At := Now;
   end Take_Due;

   function Targets_Set_For (Scan : Session; Rows, Selection : Natural) return Boolean is
     (Scan.Set_For_Rows = Rows and then Scan.Set_For_Selection = Selection);

   procedure Note_Targets_Set_For (Scan : in out Session; Rows, Selection : Natural) is
   begin
      Scan.Set_For_Rows := Rows;
      Scan.Set_For_Selection := Selection;
   end Note_Targets_Set_For;

   function Is_Active (Scan : Session) return Boolean is
   begin
      return Files.Process_Jobs.Active (Scan.Job);
   end Is_Active;

   procedure Request (Scan : in out Session; Path : String) is
      Paths : Path_Vectors.Vector;
   begin
      Paths.Append (To_Unbounded_String (Path));
      Set_Targets (Scan, Paths);
   end Request;

   procedure Run_Helper (Directory : String) is
      Paths : constant Path_Vectors.Vector :=
        Read_Request (Hostkit.Fs.Join (Directory, Files.Process_Jobs.Request_File));
   begin
      for Index in 1 .. Natural (Paths.Length) loop
         exit when Files.Job_Context.Cancelled;
         declare
            procedure Write (Stream : not null access Ada.Streams.Root_Stream_Type'Class) is
            begin
               Write_Result (Stream, Files.File_System.Directory_Size (To_String (Paths (Index))));
            end Write;
         begin
            --  Published whole: the window reads a result only once it has
            --  this name.
            Files.Job_Records.Publish_Result (Directory, Write'Access, Name => Result_Name (Index));
         end;
      end loop;
   end Run_Helper;
end Files.Folder_Size;
