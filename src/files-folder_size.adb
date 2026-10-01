with Ada.Streams.Stream_IO;
with Hostkit.Fs;

package body Files.Folder_Size is
   use Ada.Strings.Unbounded;

   Default_Scan : Session;

   procedure Close (File : in out Ada.Streams.Stream_IO.File_Type) is
   begin
      if Ada.Streams.Stream_IO.Is_Open (File) then
         Ada.Streams.Stream_IO.Close (File);
      end if;
   exception
      when others => null;
   end Close;

   procedure Start_Next (Scan : in out Session) is
      File : Ada.Streams.Stream_IO.File_Type;
   begin
      while not Scan.Targets.Is_Empty loop
         Scan.Target_Path := Scan.Targets.First_Element;
         Scan.Targets.Delete_First;
         begin
            Files.Process_Jobs.Reserve (Scan.Job);
            Ada.Streams.Stream_IO.Create
              (File, Ada.Streams.Stream_IO.Out_File, Files.Process_Jobs.Path (Scan.Job, "request"));
            Unbounded_String'Output (Ada.Streams.Stream_IO.Stream (File), Scan.Target_Path);
            Ada.Streams.Stream_IO.Close (File);
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
      Keep : constant Boolean := Files.Process_Jobs.Active (Scan.Job) and then Paths.Contains (Scan.Target_Path);
   begin
      Scan.Targets.Clear;
      for P of Paths loop
         if (not Keep or else P /= Scan.Target_Path) and then not Scan.Targets.Contains (P) then
            Scan.Targets.Append (P);
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
      File : Ada.Streams.Stream_IO.File_Type;
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
            Ada.Streams.Stream_IO.Open
              (File, Ada.Streams.Stream_IO.In_File, Files.Process_Jobs.Path (Scan.Job, "result"));
            Result := Files.File_System.Directory_Size_Result'Input (Ada.Streams.Stream_IO.Stream (File));
            Ada.Streams.Stream_IO.Close (File);
         exception
            when others => Close (File); Result := (others => <>);
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

   procedure Set_Targets (Paths : Path_Vectors.Vector) is
   begin
      Set_Targets (Default_Scan, Paths);
   end Set_Targets;

   procedure Request (Path : String) is
      Paths : Path_Vectors.Vector;
   begin
      Paths.Append (To_Unbounded_String (Path));
      Set_Targets (Default_Scan, Paths);
   end Request;

   procedure Cancel is
   begin
      Cancel (Default_Scan);
   end Cancel;

   procedure Step (Budget : Natural := 4000) is
   begin
      Step (Default_Scan, Budget);
   end Step;

   procedure Take
     (Path : out Unbounded_String;
      Result : out Files.File_System.Directory_Size_Result;
      Available : out Boolean) is
   begin
      Take (Default_Scan, Path, Result, Available);
   end Take;

   function Is_Active return Boolean is (Is_Active (Default_Scan));
   function Target_For_Test return String is (Target_For_Test (Default_Scan));

   procedure Run_Helper (Directory : String) is
      File : Ada.Streams.Stream_IO.File_Type;
      Path : Unbounded_String;
      Result : Files.File_System.Directory_Size_Result;
   begin
      Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, Hostkit.Fs.Join (Directory, "request"));
      Path := Unbounded_String'Input (Ada.Streams.Stream_IO.Stream (File));
      Ada.Streams.Stream_IO.Close (File);
      Result := Files.File_System.Directory_Size (To_String (Path));
      Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Hostkit.Fs.Join (Directory, "result"));
      Files.File_System.Directory_Size_Result'Output (Ada.Streams.Stream_IO.Stream (File), Result);
      Ada.Streams.Stream_IO.Close (File);
   exception
      when others => Close (File);
   end Run_Helper;
end Files.Folder_Size;
