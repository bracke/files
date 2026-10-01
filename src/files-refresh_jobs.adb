with Ada.Directories;
with Ada.Streams.Stream_IO;
with Ada.Strings.Unbounded;
with Files.File_System;
with Files.Durable_Writes;
with Files.Job_Context;
with Hostkit.Fs;
with Hostkit.Watch;

package body Files.Refresh_Jobs is
   use Ada.Strings.Unbounded;
   use type Files.Settings.Settings_Model;

   type Request is record
      Root : Files.Types.UString;
      Revision : Natural;
      Settings : Files.Settings.Settings_Model;
      Previous : Files.File_System.Directory_Signature;
      Recent : Boolean;
      Force : Boolean;
      Selection : Files.Types.UString;
      Error_Key : Files.Types.UString;
   end record;

   type Outcome is record
      Success : Boolean := False;
      Reloaded : Boolean := False;
      Items : Files.File_System.Item_Vectors.Vector;
      Signature : Files.File_System.Directory_Signature;
      Error_Key : Files.Types.UString;
   end record;

   procedure Close (File : in out Ada.Streams.Stream_IO.File_Type) is
   begin
      if Ada.Streams.Stream_IO.Is_Open (File) then
         Ada.Streams.Stream_IO.Close (File);
      end if;
   exception
      when others => null;
   end Close;

   procedure Cancel (Model : in out Files.Model.Window_Model) is
      Empty : Files.Process_Jobs.Session;
   begin
      Files.Model.Set_Background_Refresh (Model, Empty);
   end Cancel;

   function Start
     (Model : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Force : Boolean := False;
      Select_Name : String := "") return Files.Operations.Operation_Result
   is
      Job : Files.Process_Jobs.Session;
      File : Ada.Streams.Stream_IO.File_Type;
      Previous_Error : constant String := Files.Model.Last_Error_Key (Model);
      Work : constant Request :=
        (Root => To_Unbounded_String (Files.Model.Current_Path (Model)),
         Revision => Files.Model.Revision (Model), Settings => Settings,
         Previous => Files.Model.Directory_Signature_Of (Model),
         --  A failed listing must be retried even when the directory signature
         --  is unchanged. Preserve operation errors, which a reload cannot fix.
         Recent => Files.Model.In_Recent_View (Model),
         Force => Force or else Previous_Error = "error.directory.load",
         Selection => To_Unbounded_String
           (if Select_Name = "" then Files.Model.Selected_Name (Model) else Select_Name),
         Error_Key => (if Previous_Error = "error.directory.load" then Null_Unbounded_String
                       else To_Unbounded_String (Previous_Error)));
   begin
      if Files.Model.Paste_Execution_Is_Active (Model)
        or else (not Force and then (Work.Recent or else Files.Model.Search_Results_Are_Active (Model)
                 or else Files.Model.Rename_Is_Active (Model) or else Files.Model.Temporary_Item_Is_Active (Model)
                 or else Files.Model.Command_Palette_Is_Open (Model)))
      then
         return (Status => Files.Operations.Operation_Success, others => <>);
      end if;
      if not Force and then Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model)) then
         return (Status => Files.Operations.Operation_Success, others => <>);
      end if;
      Cancel (Model);
      Files.Process_Jobs.Reserve (Job);
      Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Files.Process_Jobs.Path (Job, "request"));
      Request'Output (Ada.Streams.Stream_IO.Stream (File), Work);
      Ada.Streams.Stream_IO.Close (File);
      Files.Process_Jobs.Launch (Job, "--files-refresh");
      Files.Model.Set_Background_Refresh (Model, Job);
      return (Status => Files.Operations.Operation_Success, Path => Work.Root, others => <>);
   exception
      when others =>
         Close (File);
         if Length (Work.Error_Key) = 0 then
            Files.Model.Set_Error (Model, "error.directory.load");
         end if;
         return (Status => Files.Operations.Operation_Failed,
                 Error_Key => To_Unbounded_String (Files.Model.Last_Error_Key (Model)), others => <>);
   end Start;

   function Advance
     (Model : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model) return Boolean
   is
      Job : constant Files.Process_Jobs.Session := Files.Model.Background_Refresh (Model);
      File : Ada.Streams.Stream_IO.File_Type;
      Work : Request;
      Done : Outcome;
      Finished, Cancelled : Boolean;
      Matching : Boolean := False;
      Requested_Root : Files.Types.UString;
      Requested_Revision : Natural;
   begin
      if not Files.Process_Jobs.Active (Job) then
         return False;
      end if;
      if Files.Model.Paste_Execution_Is_Active (Model) then
         Cancel (Model);
         return False;
      end if;
      --  Read only the request header from local transport. A navigation or edit
      --  must discard even a helper still blocked on the previous directory.
      Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, Files.Process_Jobs.Path (Job, "request"));
      Requested_Root := Files.Types.UString'Input (Ada.Streams.Stream_IO.Stream (File));
      Requested_Revision := Natural'Input (Ada.Streams.Stream_IO.Stream (File));
      Ada.Streams.Stream_IO.Close (File);
      if Requested_Root /= Files.Model.Current_Path (Model)
        or else Requested_Revision /= Files.Model.Revision (Model)
      then
         Cancel (Model);
         return False;
      end if;
      Files.Process_Jobs.Poll (Job, Finished, Cancelled);
      if not Finished then
         return False;
      end if;
      Cancel (Model); --  Job keeps the finished transport alive through result collection.
      Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, Files.Process_Jobs.Path (Job, "request"));
      Work := Request'Input (Ada.Streams.Stream_IO.Stream (File));
      Ada.Streams.Stream_IO.Close (File);
      Matching := Work.Root = Files.Model.Current_Path (Model)
        and then Work.Recent = Files.Model.In_Recent_View (Model)
        and then Work.Revision = Files.Model.Revision (Model) and then Work.Settings = Settings;
      if not Matching or else Cancelled then
         return False;
      end if;
      Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, Files.Process_Jobs.Path (Job, "result"));
      Done := Outcome'Input (Ada.Streams.Stream_IO.Stream (File));
      Ada.Streams.Stream_IO.Close (File);
      if not Done.Success then
         if Length (Work.Error_Key) = 0 then
            Files.Model.Set_Error (Model, To_String (Done.Error_Key));
         end if;
         return False;
      end if;
      if Done.Reloaded then
         if Work.Recent then
            Files.Model.Navigate_Recent (Model, Done.Items);
         else
            Files.Model.Replace_Items (Model, Done.Items);
            Files.Model.Clear_Search_Results (Model);
         end if;
         if Length (Work.Selection) > 0 then
            declare
               Selected : constant Boolean := Files.Model.Select_By_Name (Model, To_String (Work.Selection));
               pragma Unreferenced (Selected);
            begin
               null;
            end;
         end if;
      end if;
      if Files.Model.Last_Error_Key (Model) /= To_String (Work.Error_Key) then
         Files.Model.Set_Error (Model, To_String (Work.Error_Key));
      end if;
      Files.Model.Set_Directory_Signature (Model, Done.Signature);
      Files.Model.Ensure_Selected_Item_Extra (Model);
      return Done.Reloaded;
   exception
      when others =>
         Close (File);
         Cancel (Model);
         if Matching and then Length (Work.Error_Key) = 0 then
            Files.Model.Set_Error (Model, "error.directory.load");
         end if;
         return False;
   end Advance;

   procedure Run_Helper (Directory : String) is
      File : Ada.Streams.Stream_IO.File_Type;
      Work : Request;
      Done : Outcome;
   begin
      Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, Hostkit.Fs.Join (Directory, "request"));
      Work := Request'Input (Ada.Streams.Stream_IO.Stream (File));
      Ada.Streams.Stream_IO.Close (File);
      if Work.Recent then
         for Path of Files.Settings.Recent_Paths (Work.Settings) loop
            declare
               Loaded : constant Files.File_System.Item_Load_Result :=
                 Files.File_System.Load_Item (To_String (Path), Work.Settings);
            begin
               if Loaded.Success then
                  Done.Items.Append (Loaded.Item);
               end if;
            end;
         end loop;
         Done.Signature := Work.Previous;
         Done.Success := True;
         Done.Reloaded := True;
      else
         declare
            Change : constant Files.File_System.Directory_Change_Result :=
              Files.File_System.Detect_Directory_Change (Work.Previous, To_String (Work.Root));
         begin
            Done.Signature := Change.After_State;
            Done.Error_Key := Change.Error_Key;
            if Length (Change.Error_Key) = 0 then
               Done.Success := True;
               if Work.Force or else Change.Changed then
                  declare
                     Loaded : constant Files.File_System.Directory_Load_Result :=
                       Files.File_System.Load_Directory (To_String (Work.Root), Work.Settings);
                  begin
                     Done.Success := Loaded.Success;
                     Done.Reloaded := Loaded.Success;
                     Done.Items := Loaded.Items;
                     Done.Error_Key := Loaded.Error_Key;
                     --  Use the signature from before loading, so a concurrent
                     --  change during enumeration schedules another refresh.
                  end;
               end if;
            end if;
         end;
      end if;
      Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Hostkit.Fs.Join (Directory, "result.tmp"));
      Outcome'Output (Ada.Streams.Stream_IO.Stream (File), Done);
      Ada.Streams.Stream_IO.Close (File);
      if not Files.Durable_Writes.Publish
        (Hostkit.Fs.Join (Directory, "result.tmp"), Hostkit.Fs.Join (Directory, "result"))
      then
         raise Ada.Directories.Use_Error;
      end if;
   exception
      when others =>
         Close (File);
         raise;
   end Run_Helper;

   procedure Release_Watch (Job : in out Watch_Session) is
   begin
      Files.Process_Jobs.Reset (Job.Process);
      Job.Path := Null_Unbounded_String;
   end Release_Watch;

   procedure Watch_Path (Job : in out Watch_Session; Path : String) is
      File : Ada.Streams.Stream_IO.File_Type;
   begin
      if Job.Path = Path then
         return;
      end if;
      Release_Watch (Job);
      if Path = "" then
         return;
      end if;
      Files.Process_Jobs.Reserve (Job.Process);
      Ada.Streams.Stream_IO.Create
        (File, Ada.Streams.Stream_IO.Out_File, Files.Process_Jobs.Path (Job.Process, "request"));
      String'Output (Ada.Streams.Stream_IO.Stream (File), Path);
      Ada.Streams.Stream_IO.Close (File);
      Files.Process_Jobs.Launch (Job.Process, "--files-watch");
      Job.Path := To_Unbounded_String (Path);
   exception
      when others =>
         Close (File);
         Release_Watch (Job);
   end Watch_Path;

   function Poll_Watch (Job : in out Watch_Session) return Boolean is
      Finished, Cancelled : Boolean;
   begin
      if not Files.Process_Jobs.Active (Job.Process) then
         return False;
      end if;
      Files.Process_Jobs.Poll (Job.Process, Finished, Cancelled);
      if Finished then
         Release_Watch (Job);
         return False;
      end if;
      if Ada.Directories.Exists (Files.Process_Jobs.Path (Job.Process, "changed")) then
         Ada.Directories.Delete_File (Files.Process_Jobs.Path (Job.Process, "changed"));
         return True;
      end if;
      return False;
   exception
      when others => return False;
   end Poll_Watch;

   procedure Run_Watch_Helper (Directory : String) is
      File : Ada.Streams.Stream_IO.File_Type;
      Watch : Hostkit.Watch.Watch_State;
   begin
      Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, Hostkit.Fs.Join (Directory, "request"));
      declare
         Path : constant String := String'Input (Ada.Streams.Stream_IO.Stream (File));
      begin
         Ada.Streams.Stream_IO.Close (File);
         Hostkit.Watch.Watch_Path (Watch, Path);
      end;
      loop
         exit when Files.Job_Context.Cancelled;
         if Hostkit.Watch.Poll (Watch) then
            Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File,
                                         Hostkit.Fs.Join (Directory, "changed.tmp"));
            Ada.Streams.Stream_IO.Close (File);
            declare
               Posted : constant Boolean := Files.Durable_Writes.Publish
                 (Hostkit.Fs.Join (Directory, "changed.tmp"), Hostkit.Fs.Join (Directory, "changed"));
               pragma Unreferenced (Posted);
            begin
               null;
            end;
         end if;
         delay 0.05;
      end loop;
      Hostkit.Watch.Release (Watch);
   exception
      when others =>
         Close (File);
         Hostkit.Watch.Release (Watch);
   end Run_Watch_Helper;
end Files.Refresh_Jobs;
