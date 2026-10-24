with Files.Diagnostics;
with Ada.Directories;
with Ada.IO_Exceptions;
with Ada.Streams;
with Ada.Strings.Unbounded;
with GNAT.OS_Lib;
with Files.Bounded_Streams;
with Files.File_System;
with Files.Durable_Writes;
with Files.Exclusive_Streams;
with Files.Job_Context;
with Files.Job_Records;
with Files.Lease_Streams;
with Hostkit.Fs;
with Hostkit.Lease_Files;
with Hostkit.Watch;

package body Files.Refresh_Jobs is
   use Ada.Strings.Unbounded;
   use type Ada.Directories.File_Kind;
   use type Files.Operations.Operation_Status;
   use type Files.Settings.Settings_Model;
   use type Hostkit.Lease_Files.Open_Outcome;

   Max_Watch_Path_Length : constant := 32 * 1024;
   Request_Header : constant String := "files-refresh-request-1";
   Result_Header : constant String := "files-refresh-result-1";

   type Request is record
      Root : Files.Types.UString;
      Context_Revision : Natural;
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

   function Nul_Free (Value : String) return Boolean is
   begin
      for Item of Value loop
         if Item = ASCII.NUL then
            return False;
         end if;
      end loop;
      return True;
   end Nul_Free;

   function Valid_Absolute_Path (Path : String) return Boolean is
   begin
      return Path /= ""
        and then Nul_Free (Path)
        and then GNAT.OS_Lib.Is_Absolute_Path (Path);
   exception
      when others =>
         return False;
   end Valid_Absolute_Path;

   function Request_Paths_Are_Consistent
     (Root, Previous_Path : String;
      Recent              : Boolean) return Boolean is
   begin
      if Recent then
         return Root = "" and then Previous_Path = "";
      end if;
      return Valid_Absolute_Path (Root)
        and then Valid_Absolute_Path (Previous_Path);
   end Request_Paths_Are_Consistent;

   function Watch_Path_Is_Consistent (Path : String) return Boolean is
     (Path'Length <= Max_Watch_Path_Length
      and then Valid_Absolute_Path (Path));

   function Is_Consistent (Done : Outcome) return Boolean is
     (Done.Success = (Length (Done.Error_Key) = 0)
      and then (not Done.Reloaded or else Done.Success));

   procedure Write_Request
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Work : Request)
   is
   begin
      if not Request_Paths_Are_Consistent
        (To_String (Work.Root), To_String (Work.Previous.Path), Work.Recent)
      then
         raise Ada.Directories.Use_Error;
      end if;
      String'Output (Stream, Request_Header);
      Files.Job_Records.Write_String
        (Stream, To_String (Work.Root), Files.Job_Records.Max_Path_Length);
      Natural'Output (Stream, Work.Context_Revision);
      Files.Job_Records.Write_Settings (Stream, Work.Settings);
      Files.Job_Records.Write_Signature (Stream, Work.Previous);
      Boolean'Output (Stream, Work.Recent);
      Boolean'Output (Stream, Work.Force);
      Files.Job_Records.Write_String
        (Stream, To_String (Work.Selection), Files.Job_Records.Max_Path_Length);
      Files.Job_Records.Write_String
        (Stream, To_String (Work.Error_Key), Files.Job_Records.Max_Error_Length);
   end Write_Request;

   function Open_Transport
     (Path : String;
      Input : in out Files.Lease_Streams.Input_Stream) return Boolean is
     (Files.Lease_Streams.Open (Path, Input) = Hostkit.Lease_Files.Opened
      and then Files.Lease_Streams.Size (Input) <=
        Long_Long_Integer (Files.Job_Records.Max_Transport_Bytes));

   function Read_Request (Path : String) return Request
   is
      Input : aliased Files.Lease_Streams.Input_Stream;
      Work : Request;
   begin
      if not Open_Transport (Path, Input) then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      if Files.Job_Records.Read_String
        (Input'Access, Request_Header'Length) /= Request_Header
      then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      Work.Root := To_Unbounded_String
        (Files.Job_Records.Read_String
           (Input'Access, Files.Job_Records.Max_Path_Length));
      Work.Context_Revision := Natural'Input (Input'Access);
      Work.Settings := Files.Job_Records.Read_Settings (Input'Access);
      Work.Previous := Files.Job_Records.Read_Signature (Input'Access);
      Work.Recent := Boolean'Input (Input'Access);
      Work.Force := Boolean'Input (Input'Access);
      Work.Selection := To_Unbounded_String
        (Files.Job_Records.Read_String
           (Input'Access, Files.Job_Records.Max_Path_Length));
      Work.Error_Key := To_Unbounded_String
        (Files.Job_Records.Read_String
           (Input'Access, Files.Job_Records.Max_Error_Length));
      if not Files.Lease_Streams.End_Of_Stream (Input) then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      if not Request_Paths_Are_Consistent
        (To_String (Work.Root), To_String (Work.Previous.Path), Work.Recent)
      then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      Files.Lease_Streams.Release (Input);
      return Work;
   exception
      when others =>
         Files.Lease_Streams.Release (Input);
         raise;
   end Read_Request;

   procedure Read_Request_Identity
     (Path : String;
      Root : out Files.Types.UString;
      Context_Revision : out Natural)
   is
      Input : aliased Files.Lease_Streams.Input_Stream;
   begin
      if not Open_Transport (Path, Input)
        or else Files.Job_Records.Read_String
          (Input'Access, Request_Header'Length) /= Request_Header
      then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      Root := To_Unbounded_String
        (Files.Job_Records.Read_String
           (Input'Access, Files.Job_Records.Max_Path_Length));
      Context_Revision := Natural'Input (Input'Access);
      if Length (Root) > 0
        and then not Valid_Absolute_Path (To_String (Root))
      then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      Files.Lease_Streams.Release (Input);
   exception
      when others =>
         Files.Lease_Streams.Release (Input);
         raise;
   end Read_Request_Identity;

   procedure Write_Outcome
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Done : Outcome)
   is
   begin
      if not Is_Consistent (Done) then
         raise Ada.IO_Exceptions.Use_Error;
      end if;
      String'Output (Stream, Result_Header);
      Boolean'Output (Stream, Done.Success);
      Boolean'Output (Stream, Done.Reloaded);
      Files.Job_Records.Write_Items (Stream, Done.Items);
      Files.Job_Records.Write_Signature (Stream, Done.Signature);
      Files.Job_Records.Write_String
        (Stream, To_String (Done.Error_Key), Files.Job_Records.Max_Error_Length);
   end Write_Outcome;

   function Read_Outcome (Path : String) return Outcome
   is
      Input : aliased Files.Lease_Streams.Input_Stream;
      Done : Outcome;
   begin
      if not Open_Transport (Path, Input) then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      if Files.Job_Records.Read_String
        (Input'Access, Result_Header'Length) /= Result_Header
      then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      Done.Success := Boolean'Input (Input'Access);
      Done.Reloaded := Boolean'Input (Input'Access);
      Done.Items := Files.Job_Records.Read_Items (Input'Access);
      Done.Signature := Files.Job_Records.Read_Signature (Input'Access);
      Done.Error_Key := To_Unbounded_String
        (Files.Job_Records.Read_String
           (Input'Access, Files.Job_Records.Max_Error_Length));
      if not Files.Lease_Streams.End_Of_Stream (Input) then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      if not Is_Consistent (Done) then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      Files.Lease_Streams.Release (Input);
      return Done;
   exception
      when others =>
         Files.Lease_Streams.Release (Input);
         raise;
   end Read_Outcome;

   procedure Close (File : in out Files.Exclusive_Streams.Output_Stream) is
   begin
      Files.Exclusive_Streams.Close_Safely (File);
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
      File : aliased Files.Exclusive_Streams.Output_Stream;
      Previous_Error : constant String := Files.Model.Last_Error_Key (Model);
      Work : constant Request :=
        (Root => To_Unbounded_String (Files.Model.Current_Path (Model)),
         Context_Revision => Files.Model.Listing_Revision (Model), Settings => Settings,
         Previous => Files.Model.Directory_Signature_Of (Model),
         --  A failed listing must be retried even when the directory signature
         --  is unchanged. Preserve operation errors, which a reload cannot fix.
         Recent => Files.Model.In_Recent_View (Model),
         Force => Force or else Previous_Error = "error.directory.load",
         --  An empty value means preserve the selection that is current when
         --  the read completes. A nonempty operation-requested name wins.
         Selection => To_Unbounded_String (Select_Name),
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
      Files.Exclusive_Streams.Create
        (File, Files.Process_Jobs.Path (Job, "request"));
      Write_Request (File'Access, Work);
      Files.Job_Records.Validate_Size (Files.Exclusive_Streams.Size (File));
      Files.Exclusive_Streams.Close (File);
      Files.Process_Jobs.Launch (Job, "--files-refresh");
      Files.Model.Set_Background_Refresh (Model, Job);
      --  This read covers the current view, so any reload owed to it is paid.
      Files.Model.Clear_Owed_Refresh (Model);
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

   procedure Resume_Owed
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model) is
   begin
      if not Files.Model.Refresh_Is_Owed (Model)
        or else Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model))
        or else Files.Model.Paste_Execution_Is_Active (Model)
      then
         return;
      end if;

      declare
         Retry : constant Files.Operations.Operation_Result :=
           Start (Model, Settings,
                  Force       => Files.Model.Owed_Refresh_Force (Model),
                  Select_Name => Files.Model.Owed_Refresh_Selection (Model));
      begin
         --  A launch settles the debt inside Start. A launch failure has
         --  already reported its error; retrying it every poll would not help.
         if Retry.Status = Files.Operations.Operation_Failed then
            Files.Model.Clear_Owed_Refresh (Model);
         end if;
      end;
   end Resume_Owed;

   function Advance
     (Model : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model) return Boolean
   is
      Job : constant Files.Process_Jobs.Session := Files.Model.Background_Refresh (Model);
      Work : Request;
      Done : Outcome;
      Finished, Cancelled : Boolean;
      Matching : Boolean := False;
      Requested_Root : Files.Types.UString;
      Requested_Context_Revision : Natural;

      --  A read of the directory still on screen went stale because something
      --  listing-visible changed (an error, an edit, Settings). Its answer must
      --  not be applied, but the reload it stood for is still owed; Resume_Owed
      --  reissues it against the current state on a later poll.
      procedure Owe_Reload is
      begin
         declare
            Stale : constant Request :=
              Read_Request (Files.Process_Jobs.Path (Job, "request"));
         begin
            Files.Model.Note_Owed_Refresh
              (Model, Stale.Force, To_String (Stale.Selection));
         end;
      exception
         when others =>
            Files.Model.Note_Owed_Refresh (Model, False, "");
      end Owe_Reload;
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
      Read_Request_Identity
        (Files.Process_Jobs.Path (Job, "request"),
         Requested_Root, Requested_Context_Revision);
      if Requested_Root /= Files.Model.Current_Path (Model) then
         Cancel (Model);
         return False;
      elsif Requested_Context_Revision /= Files.Model.Listing_Revision (Model) then
         Owe_Reload;
         Cancel (Model);
         return False;
      elsif Files.Model.Command_Palette_Is_Open (Model)
        or else Files.Model.Rename_Is_Active (Model)
        or else Files.Model.Temporary_Item_Is_Active (Model)
      then
         --  Replacing the items would close the palette or drop the edit the
         --  user opened while this read ran: keep the result until they finish.
         return False;
      end if;
      Files.Process_Jobs.Poll (Job, Finished, Cancelled);
      if not Finished then
         return False;
      end if;
      Cancel (Model); --  Job keeps the finished transport alive through result collection.
      Work := Read_Request (Files.Process_Jobs.Path (Job, "request"));
      Matching := Work.Root = Files.Model.Current_Path (Model)
        and then Work.Recent = Files.Model.In_Recent_View (Model)
        and then Work.Context_Revision = Files.Model.Listing_Revision (Model)
        and then Work.Settings = Settings;
      if not Matching and then not Cancelled
        and then Work.Root = Files.Model.Current_Path (Model)
      then
         Owe_Reload;
      end if;
      if not Matching or else Cancelled then
         return False;
      end if;
      Done := Read_Outcome (Files.Process_Jobs.Path (Job, "result"));
      if not Done.Success then
         if Length (Work.Error_Key) = 0 then
            Files.Model.Set_Error (Model, To_String (Done.Error_Key));
         end if;
         return False;
      end if;
      if Done.Reloaded then
         declare
            Previous_Selection : constant Files.File_System.Item_Vectors.Vector :=
              Files.Model.Selected_Items (Model);
            Previous_Primary : constant Files.Types.UString :=
              Files.Model.Selected_Item (Model).Full_Path;
            --  A refresh of the folder in view keeps where the user was: its
            --  scroll, and a Quick Look whose item is still there.
            Previous_Scroll  : constant Natural := Files.Model.Main_View_Scroll_Lines (Model);
            Previewing       : constant Boolean := Files.Model.Quick_Look_Is_Open (Model);
            Previewed        : constant String := Files.Model.Quick_Look_Path (Model);
         begin
            if Work.Recent then
               Files.Model.Navigate_Recent (Model, Done.Items);
            else
               Files.Model.Replace_Items (Model, Done.Items);
               Files.Model.Clear_Search_Results (Model);
            end if;
            if Length (Work.Selection) > 0 then
               declare
                  Selected : constant Boolean :=
                    Files.Model.Select_By_Name (Model, To_String (Work.Selection));
                  pragma Unreferenced (Selected);
               begin
                  null;
               end;
            else
               Files.Model.Restore_Selection
                 (Model, Previous_Selection, To_String (Previous_Primary));
            end if;
            if not Work.Recent then
               Files.Model.Set_Main_View_Scroll_Lines (Model, Previous_Scroll);
            end if;
            if Previewing
              and then Previewed /= ""
              and then To_String (Files.Model.Selected_Item (Model).Full_Path) = Previewed
            then
               --  Prepared afresh: the change being picked up may be to it.
               Files.Model.Open_Quick_Look
                 (Model, Files.Operations.Prepare_Quick_Look (Files.Model.Selected_Item (Model)));
            end if;
         end;
      end if;
      if Files.Model.Last_Error_Key (Model) /= To_String (Work.Error_Key) then
         Files.Model.Set_Error (Model, To_String (Work.Error_Key));
      end if;
      Files.Model.Set_Directory_Signature (Model, Done.Signature);
      Files.Model.Ensure_Selected_Item_Extra (Model);
      return Done.Reloaded;
   exception
      when others =>
         Cancel (Model);
         if Matching and then Length (Work.Error_Key) = 0 then
            Files.Model.Set_Error (Model, "error.directory.load");
         end if;
         return False;
   end Advance;

   procedure Run_Helper (Directory : String) is
      File : aliased Files.Exclusive_Streams.Output_Stream;
      Work : Request;
      Done : Outcome;
   begin
      Work := Read_Request (Hostkit.Fs.Join (Directory, "request"));
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
      Files.Exclusive_Streams.Create
        (File, Hostkit.Fs.Join (Directory, "result.tmp"));
      Write_Outcome (File'Access, Done);
      Files.Job_Records.Validate_Size (Files.Exclusive_Streams.Size (File));
      Files.Exclusive_Streams.Close (File);
      if not Files.Durable_Writes.Published
        (Files.Durable_Writes.Publish
           (Hostkit.Fs.Join (Directory, "result.tmp"), Hostkit.Fs.Join (Directory, "result")))
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

   Watch_Retry_Delay : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Seconds (5);

   procedure Watch_Path (Job : in out Watch_Session; Path : String) is
      use type Ada.Real_Time.Time;
      File : aliased Files.Exclusive_Streams.Output_Stream;

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
      Files.Process_Jobs.Reserve (Job.Process);
      Files.Exclusive_Streams.Create
        (File, Files.Process_Jobs.Path (Job.Process, "request"));
      Files.Job_Records.Write_String
        (File'Access, Path, Max_Watch_Path_Length);
      Files.Exclusive_Streams.Close (File);
      Files.Process_Jobs.Launch (Job.Process, "--files-watch");
      Job.Path := To_Unbounded_String (Path);
   exception
      when others =>
         Close (File);
         Release_Watch (Job);
         Note_Failure;
   end Watch_Path;

   function Claim_Watch_Notification (Directory : String) return Boolean is
     (Hostkit.Fs.Move_No_Replace
        (Hostkit.Fs.Join (Directory, "changed"),
         Hostkit.Fs.Join (Directory, "changed.claimed")));

   function Post_Watch_Notification (Directory : String) return Boolean is
      File      : Files.Exclusive_Streams.Output_Stream;
      Temporary : constant String := Hostkit.Fs.Join (Directory, "changed.tmp");
      Target    : constant String := Hostkit.Fs.Join (Directory, "changed");
      --  A temporary left by a failed publish would make every later
      --  create-new fail, silently ending native watching for this helper.
      procedure Remove_Temporary is
      begin
         if not Hostkit.Fs.Is_Link (Temporary)
           and then Ada.Directories.Exists (Temporary)
           and then Ada.Directories.Kind (Temporary) = Ada.Directories.Ordinary_File
         then
            Ada.Directories.Delete_File (Temporary);
         end if;
      exception
         when Swallowed : others =>
            Files.Diagnostics.Note (Swallowed, "Files.Refresh_Jobs");
      end Remove_Temporary;
   begin
      Files.Exclusive_Streams.Create (File, Temporary);
      Files.Exclusive_Streams.Close (File);
      if Files.Durable_Writes.Published (Files.Durable_Writes.Publish (Temporary, Target)) then
         return True;
      end if;
      Remove_Temporary;
      return False;
   exception
      when others =>
         Close (File);
         Remove_Temporary;
         return False;
   end Post_Watch_Notification;

   function Poll_Watch (Job : in out Watch_Session) return Boolean is
      Finished, Cancelled : Boolean;
      Directory : constant String := Files.Process_Jobs.Path (Job.Process, "");
      Claimed : constant String := Hostkit.Fs.Join (Directory, "changed.claimed");

      procedure Remove_Claim is
      begin
         if Hostkit.Fs.Is_Link (Claimed) then
            declare
               Removed : constant Boolean := Hostkit.Fs.Delete_Link (Claimed);
               pragma Unreferenced (Removed);
            begin
               null;
            end;
         elsif Ada.Directories.Exists (Claimed)
           and then Ada.Directories.Kind (Claimed) = Ada.Directories.Ordinary_File
         then
            Ada.Directories.Delete_File (Claimed);
         end if;
      exception
         when Swallowed : others =>
            Files.Diagnostics.Note (Swallowed, "Files.Refresh_Jobs");
      end Remove_Claim;
   begin
      if not Files.Process_Jobs.Active (Job.Process) then
         return False;
      end if;
      Files.Process_Jobs.Poll (Job.Process, Finished, Cancelled);
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
      Remove_Claim;
      if Claim_Watch_Notification (Directory) then
         Remove_Claim;
         return True;
      end if;
      return False;
   exception
      when others => return False;
   end Poll_Watch;

   procedure Run_Watch_Helper (Directory : String) is
      Watch : Hostkit.Watch.Watch_State;
      Pending : Boolean := False;
      Input : aliased Files.Lease_Streams.Input_Stream;
   begin
      if not Open_Transport
        (Hostkit.Fs.Join (Directory, "request"), Input)
      then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      declare
         Path : constant String := Files.Bounded_Streams.Input_String
           (Input'Access, Max_Watch_Path_Length);
      begin
         if not Files.Lease_Streams.End_Of_Stream (Input)
           or else not Watch_Path_Is_Consistent (Path)
         then
            raise Ada.IO_Exceptions.Data_Error;
         end if;
         Files.Lease_Streams.Release (Input);
         Hostkit.Watch.Watch_Path (Watch, Path);
      end;
      loop
         exit when Files.Job_Context.Cancelled;
         if Hostkit.Watch.Poll (Watch) then
            Pending := True;
         end if;
         if Pending and then Post_Watch_Notification (Directory) then
            Pending := False;
         end if;
         delay 0.05;
      end loop;
      Hostkit.Watch.Release (Watch);
   exception
      when others =>
         Files.Lease_Streams.Release (Input);
         Hostkit.Watch.Release (Watch);
   end Run_Watch_Helper;
end Files.Refresh_Jobs;
