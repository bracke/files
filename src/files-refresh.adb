with Files.Model.Jobs;
with Files.Protocol_Names;
with Files.Quick_Look.Preparation;
with Files.Jobs.Helper_Modes;
with Files.Items;
with Files.Diagnostics;
with Ada.Directories;
with Ada.IO_Exceptions;
with Ada.Streams;
with Ada.Strings.Unbounded;
with Files.IO.Record_Fields;
with Files.File_System;
with Files.IO.Exclusive_Streams;
with Files.Jobs.Context;
with Files.Job_Payloads;
with Files.Jobs.Records;
with Files.IO.Lease_Streams;
with Files.IO.Fs_Primitives;
with Files.IO.Errors;
with Hostkit.Fs;
with Hostkit.Watch;
with Files.Path_Checks;
with Files.Model.Command_Palette;
with Files.Model.Quick_Look;
with Files.Model.Rename;
with Files.Model.Selection;

package body Files.Refresh is
   use Ada.Strings.Unbounded;
   use type Ada.Directories.File_Kind;
   use type Files.Operation_Results.Operation_Status;

   Max_Watch_Path_Length : constant := Files.IO.Record_Fields.Max_Path_Length;
   Request_Header : constant String := "files-refresh-request-1";
   Watch_Request_Header : constant String := "files-watch-request-1";
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
      Items : Files.Items.Item_Vectors.Vector;
      Signature : Files.File_System.Directory_Signature;
      Error_Key : Files.Types.UString;
   end record;

   function Valid_Absolute_Path (Path : String; Max_Length : Natural := Natural'Last) return Boolean
     renames Files.Path_Checks.Valid_Absolute_Path;

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
      Files.IO.Record_Fields.Output_String
        (Stream, To_String (Work.Root), Files.Jobs.Records.Max_Path_Length);
      Natural'Output (Stream, Work.Context_Revision);
      Files.Job_Payloads.Write_Settings (Stream, Work.Settings);
      Files.Jobs.Records.Write_Signature (Stream, Work.Previous);
      Boolean'Output (Stream, Work.Recent);
      Boolean'Output (Stream, Work.Force);
      Files.IO.Record_Fields.Output_String
        (Stream, To_String (Work.Selection), Files.Jobs.Records.Max_Path_Length);
      Files.IO.Record_Fields.Output_String
        (Stream, To_String (Work.Error_Key), Files.Jobs.Records.Max_Error_Length);
   end Write_Request;

   procedure Read_Request_Body
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Work   : out Request) is
   begin
      Work.Root :=
        To_Unbounded_String (Files.IO.Record_Fields.Input_String (Stream, Files.Jobs.Records.Max_Path_Length));
      Work.Context_Revision := Natural'Input (Stream);
      Work.Settings := Files.Job_Payloads.Read_Settings (Stream);
      Work.Previous := Files.Jobs.Records.Read_Signature (Stream);
      Work.Recent := Boolean'Input (Stream);
      Work.Force := Boolean'Input (Stream);
      Work.Selection :=
        To_Unbounded_String (Files.IO.Record_Fields.Input_String (Stream, Files.Jobs.Records.Max_Path_Length));
      Work.Error_Key :=
        To_Unbounded_String (Files.IO.Record_Fields.Input_String (Stream, Files.Jobs.Records.Max_Error_Length));
   end Read_Request_Body;

   function Request_Is_Consistent (Work : Request) return Boolean is
     (Request_Paths_Are_Consistent (To_String (Work.Root), To_String (Work.Previous.Path), Work.Recent));

   function Read_Request_Record is new Files.IO.Lease_Streams.Read_Record
     (Request, Read_Request_Body, Request_Is_Consistent);

   function Read_Request (Path : String) return Request is
     (Read_Request_Record (Path, Request_Header, Long_Long_Integer (Files.Jobs.Records.Max_Transport_Bytes)));

   --  A request's leading fields: what a poll compares with the window.
   type Request_Identity is record
      Root             : Files.Types.UString;
      Context_Revision : Natural := 0;
   end record;

   procedure Read_Identity_Body
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Ident  : out Request_Identity) is
   begin
      Ident.Root :=
        To_Unbounded_String (Files.IO.Record_Fields.Input_String (Stream, Files.Jobs.Records.Max_Path_Length));
      Ident.Context_Revision := Natural'Input (Stream);
   end Read_Identity_Body;

   function Identity_Is_Consistent (Ident : Request_Identity) return Boolean is
     (Length (Ident.Root) = 0 or else Valid_Absolute_Path (To_String (Ident.Root)));

   function Read_Identity_Record is new Files.IO.Lease_Streams.Read_Record
     (Request_Identity, Read_Identity_Body, Identity_Is_Consistent, Whole => False);

   function Read_Request_Identity (Path : String) return Request_Identity is
     (Read_Identity_Record (Path, Request_Header, Long_Long_Integer (Files.Jobs.Records.Max_Transport_Bytes)));

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
      Files.Job_Payloads.Write_Items (Stream, Done.Items);
      Files.Jobs.Records.Write_Signature (Stream, Done.Signature);
      Files.IO.Record_Fields.Output_String
        (Stream, To_String (Done.Error_Key), Files.Jobs.Records.Max_Error_Length);
   end Write_Outcome;

   procedure Read_Outcome_Body
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Done   : out Outcome) is
   begin
      Done.Success := Boolean'Input (Stream);
      Done.Reloaded := Boolean'Input (Stream);
      Done.Items := Files.Job_Payloads.Read_Items (Stream);
      Done.Signature := Files.Jobs.Records.Read_Signature (Stream);
      Done.Error_Key :=
        To_Unbounded_String (Files.IO.Record_Fields.Input_String (Stream, Files.Jobs.Records.Max_Error_Length));
   end Read_Outcome_Body;

   function Read_Outcome_Record is new Files.IO.Lease_Streams.Read_Record
     (Outcome, Read_Outcome_Body, Is_Consistent);

   function Read_Outcome (Path : String) return Outcome is
     (Read_Outcome_Record (Path, Result_Header, Long_Long_Integer (Files.Jobs.Records.Max_Transport_Bytes)));

   procedure Cancel (Model : in out Files.Model.Window_Model) is
      Empty : Files.Jobs.Process.Session;
   begin
      Files.Model.Jobs.Set_Background_Refresh (Model, Empty);
   end Cancel;

   function Start
     (Model : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Force : Boolean := False;
      Select_Name : String := "") return Files.Operation_Results.Operation_Result
   is
      Job : Files.Jobs.Process.Session;
      Previous_Error : constant String := Files.Model.Last_Error_Key (Model);
      Work : constant Request :=
        (Root => To_Unbounded_String (Files.Model.Current_Path (Model)),
         Context_Revision => Files.Model.Listing_Revision (Model), Settings => Settings,
         Previous => Files.Model.Directory_Signature_Of (Model),
         --  A failed listing must be retried even when the directory signature
         --  is unchanged. Preserve operation errors, which a reload cannot fix.
         Recent => Files.Model.In_Recent_View (Model),
         Force => Force or else Previous_Error = Files.IO.Errors.Directory_Load_Key,
         --  An empty value means preserve the selection that is current when
         --  the read completes. A nonempty operation-requested name wins.
         Selection => To_Unbounded_String (Select_Name),
         Error_Key => (if Previous_Error = Files.IO.Errors.Directory_Load_Key then Null_Unbounded_String
                       else To_Unbounded_String (Previous_Error)));
   begin
      if not Force and then (Work.Recent or else Files.Model.Search_Results_Are_Active (Model)) then
         return (Status => Files.Operation_Results.Operation_Success, others => <>);
      elsif Files.Model.Foreground_Job_Is_Active (Model) then
         --  The modal job's own result may not cover this read (a show-hidden
         --  change shared from another window while it ran): the reload is
         --  owed, and Resume_Owed starts it once the job is done.
         Files.Model.Note_Owed_Refresh (Model, Force => Force, Select_Name => Select_Name);
         return (Status => Files.Operation_Results.Operation_Success, others => <>);
      elsif not Force
        and then (Files.Model.Rename.Is_Active (Model) or else Files.Model.Temporary_Item_Is_Active (Model)
                  or else Files.Model.Command_Palette.Is_Open (Model))
      then
         --  Replacing the items now would drop the edit or close the palette:
         --  the reload is owed, and Resume_Owed starts it once they are done.
         Files.Model.Note_Owed_Refresh (Model, Force => False, Select_Name => Select_Name);
         return (Status => Files.Operation_Results.Operation_Success, others => <>);
      end if;
      if not Force and then Files.Jobs.Process.Active (Files.Model.Jobs.Background_Refresh (Model)) then
         return (Status => Files.Operation_Results.Operation_Success, others => <>);
      end if;
      Cancel (Model);
      Files.Jobs.Process.Reserve (Job);
      declare
         procedure Write (Stream : not null access Ada.Streams.Root_Stream_Type'Class) is
         begin
            Write_Request (Stream, Work);
         end Write;
      begin
         Files.Jobs.Process.Launch_With_Request (Job, Files.Jobs.Helper_Modes.Refresh, Write'Access);
      end;
      Files.Model.Jobs.Set_Background_Refresh (Model, Job);
      --  This read covers the current view, so any reload owed to it is paid.
      Files.Model.Clear_Owed_Refresh (Model);
      return (Status => Files.Operation_Results.Operation_Success, Path => Work.Root, others => <>);
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Refresh");
         if Length (Work.Error_Key) = 0 then
            Files.Model.Set_Error (Model, Files.IO.Errors.Directory_Load_Key);
         end if;
         return (Status => Files.Operation_Results.Operation_Failed,
                 Error_Key => To_Unbounded_String (Files.Model.Last_Error_Key (Model)), others => <>);
   end Start;

   procedure Resume_Owed
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model) is
   begin
      if not Files.Model.Refresh_Is_Owed (Model)
        or else Files.Jobs.Process.Active (Files.Model.Jobs.Background_Refresh (Model))
        or else Files.Model.Foreground_Job_Is_Active (Model)
      then
         return;
      end if;

      declare
         Retry : constant Files.Operation_Results.Operation_Result :=
           Start (Model, Settings,
                  Force       => Files.Model.Owed_Refresh_Force (Model),
                  Select_Name => Files.Model.Owed_Refresh_Selection (Model));
      begin
         --  A launch settles the debt inside Start. A launch failure has
         --  already reported its error; retrying it every poll would not help.
         if Retry.Status = Files.Operation_Results.Operation_Failed then
            Files.Model.Clear_Owed_Refresh (Model);
         end if;
      end;
   end Resume_Owed;

   --  A read of the directory still on screen went stale because something
   --  listing-visible changed (an error, an edit, Settings). Its answer must
   --  not be applied, but the reload it stood for is still owed; Resume_Owed
   --  reissues it against the current state on a later poll.
   procedure Owe_Reload (Model : in out Files.Model.Window_Model; Job : Files.Jobs.Process.Session) is
   begin
      declare
         Stale : constant Request := Read_Request (Files.Jobs.Process.Path (Job, Files.Jobs.Process.Request_File));
      begin
         Files.Model.Note_Owed_Refresh (Model, Stale.Force, To_String (Stale.Selection));
      end;
   exception
      when Failure : others =>
         Files.Diagnostics.Note (Failure, "Files.Refresh");
         Files.Model.Note_Owed_Refresh (Model, False, "");
   end Owe_Reload;

   --  The re-read items replace the shown ones, keeping where the user was:
   --  the selection (or the name the read was asked to select), the scroll,
   --  the info pane and a Quick Look whose item is still there.
   procedure Apply_Reloaded_Items
     (Model : in out Files.Model.Window_Model;
      Work  : Request;
      Items : Files.Items.Item_Vectors.Vector)
   is
      Previous_Selection : constant Files.Items.Item_Vectors.Vector :=
        Files.Model.Selection.Selected_Items (Model);
      --  The primary item as the info pane shows it, details and all.
      Previous_Item    : constant Files.Items.Directory_Item := Files.Model.Selection.Selected_Item (Model);
      Previous_Primary : constant Files.Types.UString := Previous_Item.Full_Path;
      Previous_Info    : constant Natural := Files.Model.Info_Pane_Scroll_Lines (Model);
      --  A refresh of the folder in view keeps where the user was: its
      --  scroll, and a Quick Look whose item is still there.
      Previous_Scroll  : constant Natural := Files.Model.Main_View_Scroll_Lines (Model);
      Previewing       : constant Boolean := Files.Model.Quick_Look.Is_Open (Model);
      Previewed        : constant String := Files.Model.Quick_Look.Path (Model);
      Previous_Preview : constant Files.Quick_Look.Quick_Look_Content :=
        Files.Model.Quick_Look.Content_Of (Model);
   begin
      if Work.Recent then
         Files.Model.Navigate_Recent (Model, Items);
      else
         Files.Model.Replace_Items (Model, Items);
         Files.Model.Clear_Search_Results (Model);
      end if;
      if Length (Work.Selection) > 0 then
         declare
            Selected : constant Boolean :=
              Files.Model.Selection.Select_By_Name (Model, To_String (Work.Selection));
            pragma Unreferenced (Selected);
         begin
            null;
         end;
      else
         Files.Model.Selection.Restore
           (Model, Previous_Selection, To_String (Previous_Primary));
      end if;
      if not Work.Recent then
         Files.Model.Set_Main_View_Scroll_Lines (Model, Previous_Scroll);
      end if;
      --  So does the info pane, on the same item: its scroll, and the
      --  details read for it unless a forced reload (a settings change,
      --  an explicit refresh) may have changed what they depend on.
      Files.Model.Keep_Info_Pane (Model, Previous_Item, Previous_Info, Keep_Extra => not Work.Force);
      if Previewing
        and then Previewed /= ""
        and then To_String (Files.Model.Selection.Selected_Item (Model).Full_Path) = Previewed
      then
         --  Prepared afresh when the change being picked up is to it;
         --  otherwise the preview it had, image and all, comes back.
         Files.Model.Quick_Look.Open
           (Model,
            (if Files.Quick_Look.Source_Stamp_Of (Files.Model.Selection.Selected_Item (Model))
                = Previous_Preview.Source_Stamp
             then Previous_Preview
             else Files.Quick_Look.Preparation.Prepare (Files.Model.Selection.Selected_Item (Model))));
      end if;
   end Apply_Reloaded_Items;

   function Advance
     (Model : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model) return Boolean
   is
      Job : constant Files.Jobs.Process.Session := Files.Model.Jobs.Background_Refresh (Model);
      Work : Request;
      Done : Outcome;
      Finished, Cancelled : Boolean;
      Matching : Boolean := False;
      Requested : Request_Identity;

   begin
      if not Files.Jobs.Process.Active (Job) then
         return False;
      end if;
      if Files.Model.Foreground_Job_Is_Active (Model) then
         Cancel (Model);
         return False;
      end if;
      --  Read only the request header from local transport. A navigation or edit
      --  must discard even a helper still blocked on the previous directory.
      Requested := Read_Request_Identity (Files.Jobs.Process.Path (Job, Files.Jobs.Process.Request_File));
      if Requested.Root /= Files.Model.Current_Path (Model) then
         Cancel (Model);
         return False;
      elsif Requested.Context_Revision /= Files.Model.Listing_Revision (Model) then
         Owe_Reload (Model, Job);
         Cancel (Model);
         return False;
      elsif Files.Model.Command_Palette.Is_Open (Model)
        or else Files.Model.Rename.Is_Active (Model)
        or else Files.Model.Temporary_Item_Is_Active (Model)
      then
         --  Replacing the items would close the palette or drop the edit the
         --  user opened while this read ran: keep the result until they finish.
         return False;
      end if;
      Files.Jobs.Process.Poll (Job, Finished, Cancelled);
      if not Finished then
         return False;
      end if;
      Cancel (Model); --  Job keeps the finished transport alive through result collection.
      Work := Read_Request (Files.Jobs.Process.Path (Job, Files.Jobs.Process.Request_File));
      Matching := Work.Root = Files.Model.Current_Path (Model)
        and then Work.Recent = Files.Model.In_Recent_View (Model)
        and then Work.Context_Revision = Files.Model.Listing_Revision (Model)
        and then Files.Settings.Same_Listing (Work.Settings, Settings, Work.Recent);
      if not Matching and then not Cancelled
        and then Work.Root = Files.Model.Current_Path (Model)
      then
         Owe_Reload (Model, Job);
      end if;
      if not Matching or else Cancelled then
         return False;
      end if;
      Done := Read_Outcome (Files.Jobs.Process.Path (Job, Files.Jobs.Process.Result_File));
      if not Done.Success then
         if Length (Work.Error_Key) = 0 then
            Files.Model.Set_Error (Model, To_String (Done.Error_Key));
         end if;
         return False;
      end if;
      if Done.Reloaded then
         Apply_Reloaded_Items (Model, Work, Done.Items);
      end if;
      if Files.Model.Last_Error_Key (Model) /= To_String (Work.Error_Key) then
         Files.Model.Set_Error (Model, To_String (Work.Error_Key));
      end if;
      Files.Model.Set_Directory_Signature (Model, Done.Signature);
      Ensure_Selected_Item_Extra (Model, Settings.Show_Hidden_Files);
      return Done.Reloaded;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Refresh");
         Cancel (Model);
         if Matching and then Length (Work.Error_Key) = 0 then
            Files.Model.Set_Error (Model, Files.IO.Errors.Directory_Load_Key);
         end if;
         return False;
   end Advance;

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

   procedure Run_Helper (Directory : String) is
      Work : Request;
      Done : Outcome;

      procedure Write (Stream : not null access Ada.Streams.Root_Stream_Type'Class) is
      begin
         Write_Outcome (Stream, Done);
      end Write;
   begin
      Work := Read_Request (Hostkit.Fs.Join (Directory, Files.Jobs.Process.Request_File));
      if Work.Recent then
         Done.Items := Files.File_System.Load_Recent_Items (Work.Settings);
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
                       Files.File_System.Load_Directory_Generating_Thumbnails (To_String (Work.Root), Work.Settings);
                  begin
                     Done.Success := Loaded.Success;
                     Done.Reloaded := Loaded.Success;
                     Done.Items := Loaded.Items;
                     Files.Job_Payloads.Fit_Thumbnails (Done.Items);
                     Done.Error_Key := Loaded.Error_Key;
                     --  Use the signature from before loading, so a concurrent
                     --  change during enumeration schedules another refresh.
                  end;
               end if;
            end if;
         end;
      end if;
      Files.Jobs.Records.Publish_Result (Directory, Write'Access);
   end Run_Helper;

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
         Files.Diagnostics.Note (Swallowed, "Files.Refresh");
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
         Files.Diagnostics.Note (Failure, "Files.Refresh");
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
         Files.Diagnostics.Note (Swallowed, "Files.Refresh");
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
            Files.Diagnostics.Note (Swallowed, "Files.Refresh");
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
         Files.Diagnostics.Note (Swallowed, "Files.Refresh");
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
      Last_State   : Files.File_System.Directory_Signature;
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
            Files.Diagnostics.Note (Swallowed, "Files.Refresh");
      end;
      loop
         exit when Files.Jobs.Context.Cancelled;
         if Hostkit.Watch.Poll (Watch) then
            Pending := True;
         end if;
         if Polls_Itself and then Ada.Real_Time.Clock >= Next_Scan then
            declare
               State : constant Files.File_System.Directory_Signature :=
                 Files.File_System.Directory_State (To_String (Watched));
            begin
               --  Moved, or became readable or unreadable; a folder that
               --  stays unreadable (no state either time) is not a change.
               if (State.Taken or else Last_State.Taken)
                 and then not Files.File_System.Same_State (State, Last_State)
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
         Files.Diagnostics.Note (Swallowed, "Files.Refresh");
         Hostkit.Watch.Release (Watch);
   end Run_Watch_Helper;
   procedure Ensure_Selected_Item_Extra
     (Model       : in out Files.Model.Window_Model;
      Show_Hidden : Boolean) is
   begin
      if not Files.Model.Background_Transfers (Model)
        and then Files.Model.Selected_Item_Needs_Extra (Model)
      then
         declare
            Item : constant Files.Items.Directory_Item := Files.Model.Selection.Selected_Item (Model);
         begin
            Files.Model.Set_Selected_Item_Extra
              (Model,
               Files.File_System.Extra_Info_Of
                 (To_String (Item.Full_Path), Item.Kind, To_String (Item.Filetype), Show_Hidden));
         end;
      end if;
   end Ensure_Selected_Item_Extra;

end Files.Refresh;
