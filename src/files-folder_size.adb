with Files.Fs_Primitives;
with Ada.Directories;
with Ada.Containers.Hashed_Sets;
with Ada.IO_Exceptions;
with Ada.Streams;
with Ada.Strings.Unbounded.Hash;
with GNAT.OS_Lib;
with Files.Bounded_Streams;
with Files.Exclusive_Streams;
with Files.Lease_Streams;
with Hostkit.Fs;
with Hostkit.Lease_Files;

package body Files.Folder_Size is
   use Ada.Strings.Unbounded;
   use type Hostkit.Lease_Files.Open_Outcome;

   package Path_Sets is new Ada.Containers.Hashed_Sets
     (Element_Type        => Unbounded_String,
      Hash                => Ada.Strings.Unbounded.Hash,
      Equivalent_Elements => Ada.Strings.Unbounded."=");

   Max_Request_Path_Length : constant := 32 * 1024;
   Max_Record_Bytes : constant := 64 * 1024;
   Request_Header : constant String := "files-folder-size-request-1";
   Result_Header : constant String := "files-folder-size-result-1";

   function Request_Path_Is_Valid (Path : String) return Boolean is
     (Files.Fs_Primitives.Valid_Absolute_Path (Path, Max_Request_Path_Length));

   procedure Close (File : in out Files.Exclusive_Streams.Output_Stream) is
   begin
      Files.Exclusive_Streams.Close_Safely (File);
   end Close;

   procedure Write_Request
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Path : String)
   is
   begin
      if not Request_Path_Is_Valid (Path) then
         raise Ada.Directories.Use_Error;
      end if;
      String'Output (Stream, Request_Header);
      String'Output (Stream, Path);
   end Write_Request;

   function Open_Record
     (Path : String;
      Input : in out Files.Lease_Streams.Input_Stream) return Boolean is
     (Files.Lease_Streams.Open (Path, Input) = Hostkit.Lease_Files.Opened
      and then Files.Lease_Streams.Size (Input) <=
        Long_Long_Integer (Max_Record_Bytes));

   function Read_Request (Path : String) return String
   is
      Input : aliased Files.Lease_Streams.Input_Stream;
   begin
      if not Open_Record (Path, Input) then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      if Files.Bounded_Streams.Input_String
        (Input'Access, Request_Header'Length) /= Request_Header
      then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      declare
         Path : constant String := Files.Bounded_Streams.Input_String
           (Input'Access, Max_Request_Path_Length);
      begin
         if not Files.Lease_Streams.End_Of_Stream (Input)
           or else not Request_Path_Is_Valid (Path)
         then
            raise Ada.IO_Exceptions.Data_Error;
         end if;
         Files.Lease_Streams.Release (Input);
         return Path;
      end;
   exception
      when others =>
         Files.Lease_Streams.Release (Input);
         raise;
   end Read_Request;

   procedure Write_Result
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Result : Files.File_System.Directory_Size_Result)
   is
   begin
      if Result.Total_Bytes < 0
        or else Result.File_Count > Result.Item_Count
        or else
          (not Result.Available
           and then
             (Result.Total_Bytes /= 0
              or else Result.File_Count /= 0
              or else Result.Item_Count /= 0
              or else Result.Capped))
      then
         raise Ada.Directories.Use_Error;
      end if;
      String'Output (Stream, Result_Header);
      Boolean'Output (Stream, Result.Available);
      Long_Long_Integer'Output (Stream, Result.Total_Bytes);
      Natural'Output (Stream, Result.File_Count);
      Natural'Output (Stream, Result.Item_Count);
      Boolean'Output (Stream, Result.Capped);
   end Write_Result;

   function Read_Result
     (Path : String)
      return Files.File_System.Directory_Size_Result
   is
      Input : aliased Files.Lease_Streams.Input_Stream;
      Result : Files.File_System.Directory_Size_Result;
   begin
      if not Open_Record (Path, Input) then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      if Files.Bounded_Streams.Input_String
        (Input'Access, Result_Header'Length) /= Result_Header
      then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      Result.Available := Boolean'Input (Input'Access);
      Result.Total_Bytes := Long_Long_Integer'Input (Input'Access);
      Result.File_Count := Natural'Input (Input'Access);
      Result.Item_Count := Natural'Input (Input'Access);
      Result.Capped := Boolean'Input (Input'Access);
      if Result.Total_Bytes < 0
        or else Result.File_Count > Result.Item_Count
        or else
          (not Result.Available
           and then
             (Result.Total_Bytes /= 0
              or else Result.File_Count /= 0
              or else Result.Item_Count /= 0
              or else Result.Capped))
      then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      if not Files.Lease_Streams.End_Of_Stream (Input) then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      Files.Lease_Streams.Release (Input);
      return Result;
   exception
      when others =>
         Files.Lease_Streams.Release (Input);
         raise;
   end Read_Result;

   procedure Start_Next (Scan : in out Session) is
      File : aliased Files.Exclusive_Streams.Output_Stream;
   begin
      while not Scan.Targets.Is_Empty loop
         Scan.Target_Path := Scan.Targets.First_Element;
         Scan.Targets.Delete_First;
         begin
            Files.Process_Jobs.Reserve (Scan.Job);
            Files.Exclusive_Streams.Create
              (File, Files.Process_Jobs.Path (Scan.Job, "request"));
            Write_Request
              (File'Access, To_String (Scan.Target_Path));
            Files.Exclusive_Streams.Close (File);
            Files.Process_Jobs.Launch (Scan.Job, "--files-folder-size");
            return;
         exception
            when others =>
               Close (File);
               Files.Process_Jobs.Reset (Scan.Job);
               Scan.Done_Queue.Append (Finished_Measurement'(Path => Scan.Target_Path, Result => (others => <>)));
         end;
      end loop;
      Scan.Target_Path := Null_Unbounded_String;
   end Start_Next;

   procedure Set_Targets (Scan : in out Session; Paths : Path_Vectors.Vector) is
      Requested : Path_Sets.Set;
      Keep : Boolean;
   begin
      for Path of Paths loop
         if Request_Path_Is_Valid (To_String (Path)) then
            Requested.Include (Path);
         end if;
      end loop;
      Keep := Files.Process_Jobs.Active (Scan.Job)
        and then Requested.Contains (Scan.Target_Path);
      Scan.Targets.Clear;
      for P of Paths loop
         if Request_Path_Is_Valid (To_String (P))
           and then (not Keep or else P /= Scan.Target_Path)
           and then Requested.Contains (P)
         then
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
      Files.Process_Jobs.Reset (Scan.Job);
      Scan.Targets.Clear;
      Scan.Target_Path := Null_Unbounded_String;
   end Cancel;

   procedure Step (Scan : in out Session; Budget : Natural := 4000) is
      Finished, Cancelled : Boolean;
      Result : Files.File_System.Directory_Size_Result;
   begin
      if Budget = 0 or else not Files.Process_Jobs.Active (Scan.Job) then
         return;
      end if;
      Files.Process_Jobs.Poll (Scan.Job, Finished, Cancelled);
      if not Finished then
         return;
      end if;
      if not Cancelled then
         begin
            Result := Read_Result
              (Files.Process_Jobs.Path (Scan.Job, "result"));
         exception
            when others => Result := (others => <>);
         end;
         Scan.Done_Queue.Append (Finished_Measurement'(Path => Scan.Target_Path, Result => Result));
      end if;
      Files.Process_Jobs.Reset (Scan.Job);
      Start_Next (Scan);
   end Step;

   procedure Take
     (Scan : in out Session;
      Path : out Unbounded_String;
      Result : out Files.File_System.Directory_Size_Result;
      Available : out Boolean) is
   begin
      Available := not Scan.Done_Queue.Is_Empty;
      if Available then
         Path := Scan.Done_Queue.First_Element.Path;
         Result := Scan.Done_Queue.First_Element.Result;
         Scan.Done_Queue.Delete_First;
      else
         Path := Null_Unbounded_String;
         Result := (others => <>);
      end if;
   end Take;

   function Is_Active (Scan : Session) return Boolean is
   begin
      return Files.Process_Jobs.Active (Scan.Job);
   end Is_Active;

   function Target_For_Test (Scan : Session) return String is
   begin
      return To_String (Scan.Target_Path);
   end Target_For_Test;

   procedure Request (Scan : in out Session; Path : String) is
      Paths : Path_Vectors.Vector;
   begin
      Paths.Append (To_Unbounded_String (Path));
      Set_Targets (Scan, Paths);
   end Request;

   procedure Run_Helper (Directory : String) is
      File : aliased Files.Exclusive_Streams.Output_Stream;
      Path : Unbounded_String;
      Result : Files.File_System.Directory_Size_Result;
   begin
      Path := To_Unbounded_String
        (Read_Request (Hostkit.Fs.Join (Directory, "request")));
      Result := Files.File_System.Directory_Size (To_String (Path));
      Files.Exclusive_Streams.Create
        (File, Hostkit.Fs.Join (Directory, "result"));
      Write_Result (File'Access, Result);
      Files.Exclusive_Streams.Close (File);
   exception
      when others => Close (File);
   end Run_Helper;
end Files.Folder_Size;
