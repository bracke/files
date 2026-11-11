with Files.Diagnostics;
with Files.Helper_Modes;
with Ada.Directories;
with Ada.Containers.Hashed_Sets;
with Ada.IO_Exceptions;
with Ada.Streams;
with Ada.Strings.Unbounded.Hash;
with Files.Types;
with Files.Bounded_Streams;
with Files.Job_Context;
with Files.Exclusive_Streams;
with Files.Lease_Streams;
with Files.Fs_Primitives;
with Hostkit.Fs;
with Hostkit.Lease_Files;
with Files.Path_Checks;

package body Files.Folder_Size is
   use Ada.Strings.Unbounded;
   use type Hostkit.Lease_Files.Open_Outcome;

   package Path_Sets is new Ada.Containers.Hashed_Sets
     (Element_Type        => Unbounded_String,
      Hash                => Ada.Strings.Unbounded.Hash,
      Equivalent_Elements => Ada.Strings.Unbounded."=");

   Max_Request_Path_Length : constant := Files.Bounded_Streams.Max_Path_Length;
   Max_Record_Bytes : constant := 64 * 1024;
   --  A batch request: up to Max_Batch paths, within this many bytes.
   Max_Request_Bytes : constant := 1024 * 1024;
   Request_Header : constant String := "files-folder-size-request-2";
   Result_Header : constant String := "files-folder-size-result-1";

   function Request_Path_Is_Valid (Path : String) return Boolean is
     (Files.Path_Checks.Valid_Absolute_Path (Path, Max_Request_Path_Length));

   procedure Close (File : in out Files.Exclusive_Streams.Output_Stream) is
   begin
      Files.Exclusive_Streams.Close_Safely (File);
   end Close;

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

   function Open_Record
     (Path      : String;
      Input     : in out Files.Lease_Streams.Input_Stream;
      Max_Bytes : Natural := Max_Record_Bytes) return Boolean is
     (Files.Lease_Streams.Open (Path, Input) = Hostkit.Lease_Files.Opened
      and then Files.Lease_Streams.Size (Input) <= Long_Long_Integer (Max_Bytes));

   function Read_Request (Path : String) return Path_Vectors.Vector
   is
      Input  : aliased Files.Lease_Streams.Input_Stream;
      Result : Path_Vectors.Vector;
   begin
      if not Open_Record (Path, Input, Max_Request_Bytes) then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      if Files.Bounded_Streams.Input_String
        (Input'Access, Request_Header'Length) /= Request_Header
      then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      declare
         Count : constant Natural := Natural'Input (Input'Access);
      begin
         if Count not in 1 .. Max_Batch then
            raise Ada.IO_Exceptions.Data_Error;
         end if;
         for Index in 1 .. Count loop
            declare
               Path : constant String := Files.Bounded_Streams.Input_String
                 (Input'Access, Max_Request_Path_Length);
            begin
               if not Request_Path_Is_Valid (Path) then
                  raise Ada.IO_Exceptions.Data_Error;
               end if;
               Result.Append (To_Unbounded_String (Path));
            end;
         end loop;
      end;
      if not Files.Lease_Streams.End_Of_Stream (Input) then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      Files.Lease_Streams.Release (Input);
      return Result;
   exception
      when others =>
         Files.Lease_Streams.Release (Input);
         raise;
   end Read_Request;

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

   function Is_Queued (Scan : Session; Path : Unbounded_String) return Boolean is
     (for some Done of Scan.Done_Queue => Done.Path = Path);

   procedure Start_Next (Scan : in out Session) is
      File  : aliased Files.Exclusive_Streams.Output_Stream;
      Bytes : Natural := 0;
   begin
      Scan.Batch.Clear;
      Scan.Next_Result := 1;
      --  As many as fit one request.
      while not Scan.Targets.Is_Empty
        and then Natural (Scan.Batch.Length) < Max_Batch
        and then Bytes + Length (Scan.Targets.First_Element) + 64 <= Max_Request_Bytes
      loop
         Bytes := Bytes + Length (Scan.Targets.First_Element) + 64;
         Scan.Batch.Append (Scan.Targets.First_Element);
         Scan.Targets.Delete_First;
      end loop;
      if Scan.Batch.Is_Empty then
         return;
      end if;
      Files.Process_Jobs.Reserve (Scan.Job);
      Files.Exclusive_Streams.Create (File, Files.Process_Jobs.Path (Scan.Job, Files.Process_Jobs.Request_File));
      Write_Request (File'Access, Scan.Batch);
      Files.Exclusive_Streams.Close (File);
      Files.Process_Jobs.Launch (Scan.Job, Files.Helper_Modes.Flag (Files.Helper_Modes.Folder_Size));
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Folder_Size");
         Close (File);
         Files.Process_Jobs.Reset (Scan.Job);
         --  Every directory of the batch is answered, unmeasured.
         for Path of Scan.Batch loop
            Scan.Done_Queue.Append (Measurement'(Path => Path, Result => (others => <>)));
         end loop;
         Scan.Batch.Clear;
   end Start_Next;

   procedure Set_Targets (Scan : in out Session; Paths : Path_Vectors.Vector) is
      Requested : Path_Sets.Set;
      Keep      : Boolean;
   begin
      for Path of Paths loop
         if Request_Path_Is_Valid (To_String (Path)) then
            Requested.Include (Path);
         end if;
      end loop;
      --  The running helper is kept while it has directories left to report
      --  and every one of them is still wanted; those are not asked again.
      Keep := Files.Process_Jobs.Active (Scan.Job)
        and then Scan.Next_Result <= Natural (Scan.Batch.Length)
        and then (for all Index in Scan.Next_Result .. Natural (Scan.Batch.Length) =>
                    Requested.Contains (Scan.Batch (Index)));
      if Keep then
         for Index in Scan.Next_Result .. Natural (Scan.Batch.Length) loop
            Requested.Exclude (Scan.Batch (Index));
         end loop;
      end if;
      Scan.Targets.Clear;
      for P of Paths loop
         if Requested.Contains (P) and then not Is_Queued (Scan, P) then
            Scan.Targets.Append (P);
            Requested.Delete (P);
         end if;
      end loop;
      if not Keep then
         Files.Process_Jobs.Reset (Scan.Job);
         Start_Next (Scan);
      end if;
   end Set_Targets;

   procedure Cancel (Scan : in out Session) is
   begin
      Scan.Set_For_Rows := Natural'Last;
      Scan.Set_For_Selection := Natural'Last;
      Files.Process_Jobs.Reset (Scan.Job);
      Scan.Targets.Clear;
      Scan.Batch.Clear;
      Scan.Next_Result := 1;
   end Cancel;

   --  Read the results the helper has published since the last call.
   --  Take the helper's published results, in order. A result that is there
   --  but will not open yet (on Windows, a file just renamed into place can
   --  refuse its lease for a moment: CI saw this answer a folder as
   --  unmeasured) is read again on a later pass while the helper runs. Once
   --  the helper has Finished, a few short retries, then it is unmeasured.
   procedure Collect (Scan : in out Session; Finished : Boolean) is
   begin
      while Scan.Next_Result <= Natural (Scan.Batch.Length) loop
         declare
            Name : constant String :=
              Files.Process_Jobs.Path (Scan.Job, Result_Name (Scan.Next_Result));
            Result : Files.File_System.Directory_Size_Result;
            Read   : Boolean := False;
         begin
            exit when not Files.Fs_Primitives.Exists (Name);
            for Attempt in 1 .. (if Finished then 5 else 1) loop
               begin
                  if Test_Unreadable_Results > 0 then
                     Test_Unreadable_Results := Test_Unreadable_Results - 1;
                     raise Ada.Directories.Use_Error;
                  end if;
                  Result := Read_Result (Name);
                  Read := True;
                  exit;
               exception
                  when Swallowed : others =>
                     Files.Diagnostics.Note (Swallowed, "Files.Folder_Size");
                     if Finished and then Attempt < 5 then
                        delay 0.02;
                     end if;
               end;
            end loop;
            if not Read then
               exit when not Finished;
               Result := (others => <>);
            end if;
            Scan.Done_Queue.Append (Measurement'(Path => Scan.Batch (Scan.Next_Result), Result => Result));
            Scan.Next_Result := Scan.Next_Result + 1;
         end;
      end loop;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Folder_Size");
         null;
   end Collect;

   procedure Step (Scan : in out Session) is
      Finished, Cancelled : Boolean;
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
      Files.Process_Jobs.Poll (Scan.Job, Finished, Cancelled);
      if Cancelled then
         return;
      end if;
      Collect (Scan, Finished);
      if not Finished then
         return;
      end if;
      --  What a helper that stopped early did not measure is answered,
      --  unmeasured, so the window does not wait for it.
      for Index in Scan.Next_Result .. Natural (Scan.Batch.Length) loop
         Scan.Done_Queue.Append (Measurement'(Path => Scan.Batch (Index), Result => (others => <>)));
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
            File   : aliased Files.Exclusive_Streams.Output_Stream;
            Staged : constant String := Hostkit.Fs.Join (Directory, Result_Name (Index) & ".tmp");
         begin
            Files.Exclusive_Streams.Create (File, Staged);
            Write_Result (File'Access, Files.File_System.Directory_Size (To_String (Paths (Index))));
            Files.Exclusive_Streams.Close (File);
            --  Published whole: the window reads a result only once it has
            --  this name.
            if not Hostkit.Fs.Move_No_Replace (Staged, Hostkit.Fs.Join (Directory, Result_Name (Index))) then
               raise Ada.Directories.Use_Error;
            end if;
         exception
            when others =>
               Close (File);
               raise;
         end;
      end loop;
   end Run_Helper;
end Files.Folder_Size;
