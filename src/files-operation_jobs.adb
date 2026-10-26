with Files.Fs_Primitives;
with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Strings.Hash;
with Files.Diagnostics;
with Ada.Directories;
with Ada.IO_Exceptions;
with Ada.Streams;
with Ada.Strings.Unbounded;
with GNAT.OS_Lib;

with Files.Job_Context;
with Files.Job_Records;
with Files.Lease_Streams;
with Files.Durable_Writes;
with Files.History_Journal;
with Files.Refresh_Jobs;
with Files.File_System;
with Files.Exclusive_Streams;
with Files.Types;
with Files.Paste;
with Files.Process_Jobs;
with Hostkit.Fs;
with Hostkit.Lease_Files;

package body Files.Operation_Jobs is
   use Ada.Strings.Unbounded;
   use type Files.Operations.Operation_Status;
   use type Files.Model.Undo_Action_Kind;
   use type Files.Settings.Settings_Model;
   use type Hostkit.Lease_Files.Open_Outcome;

   Request_Header : constant String := "files-operation-request-3";
   Result_Header : constant String := "files-operation-result-1";

   type Request is record
      Kind     : Operation_Kind;
      Root     : Files.Types.UString;
      Recent   : Boolean;
      Query    : Files.Types.UString;
      Selected : Files.File_System.Item_Vectors.Vector;
      Settings : Files.Settings.Settings_Model;
      Context_Revision : Natural;
      View_Incarnation : Natural;
   end record;

   type Outcome is record
      Kind      : Operation_Kind;
      Recent    : Boolean := False;
      Result    : Files.Operations.Operation_Result;
      Items     : Files.File_System.Item_Vectors.Vector;
      Selection : Files.Types.UString;
      Visible_Error : Files.Types.UString;
      Signature : Files.File_System.Directory_Signature;
      --  The renames, moves and removals the helper made (Note_Path_Move),
      --  for the window's labels and favorites to follow.
      Moved_From : Files.Types.String_Vectors.Vector;
      Moved_To   : Files.Types.String_Vectors.Vector;
   end record;

   Max_Moves : constant := 100_000;

   package Index_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Positive,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   --  At most Max_Moves, as Read_Paths accepts: past that the labels of the
   --  rest do not follow, but the operation's outcome still reads back.
   procedure Write_Paths
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Paths  : Files.Types.String_Vectors.Vector) is
      Count : constant Natural := Natural'Min (Natural (Paths.Length), Max_Moves);
   begin
      Natural'Output (Stream, Count);
      for Index in 1 .. Count loop
         Files.Job_Records.Write_String (Stream, To_String (Paths (Index)), Files.Job_Records.Max_Path_Length);
      end loop;
   end Write_Paths;

   --  The message for a job of Kind that failed without saying why.
   function Failure_Key (Kind : Operation_Kind) return String is
     (case Kind is
         when Duplicate                          => "error.duplicate.failed",
         when Compress_Zip | Compress_Seven_Zip  => "error.compress.failed",
         when Extract                            => "error.extract.failed",
         when Search_Names | Search_Contents     => "error.search.failed",
         when Trash                              => "error.trash.failed",
         when Delete_Permanently                 => "error.permanent_delete.failed",
         when Restore                            => "error.trash.restore_failed",
         when Empty_Trash                        => "error.trash.empty_failed",
         when Undo                               => "error.undo.failed",
         when Redo                               => "error.redo.failed");

   function Read_Paths
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class)
      return Files.Types.String_Vectors.Vector
   is
      Count : constant Natural := Natural'Input (Stream);
      Paths : Files.Types.String_Vectors.Vector;
   begin
      if Count > Max_Moves then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      for Index in 1 .. Count loop
         Paths.Append
           (To_Unbounded_String (Files.Job_Records.Read_String (Stream, Files.Job_Records.Max_Path_Length)));
      end loop;
      return Paths;
   end Read_Paths;

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
     (Files.Fs_Primitives.Valid_Absolute_Path (Path));

   function Request_Path_Is_Consistent
     (Root   : String;
      Recent : Boolean) return Boolean is
     ((if Recent then Root = "" else Valid_Absolute_Path (Root)));

   procedure Write_Request
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Work : Request)
   is
   begin
      if not Request_Path_Is_Consistent
        (To_String (Work.Root), Work.Recent)
      then
         raise Ada.Directories.Use_Error;
      end if;
      String'Output (Stream, Request_Header);
      Operation_Kind'Output (Stream, Work.Kind);
      Files.Job_Records.Write_String
        (Stream, To_String (Work.Root), Files.Job_Records.Max_Path_Length);
      Boolean'Output (Stream, Work.Recent);
      Files.Job_Records.Write_String
        (Stream, To_String (Work.Query), Files.Job_Records.Max_Text_Length);
      Files.Job_Records.Write_Items (Stream, Work.Selected);
      Files.Job_Records.Write_Settings (Stream, Work.Settings);
      Natural'Output (Stream, Work.Context_Revision);
      Natural'Output (Stream, Work.View_Incarnation);
   end Write_Request;

   function Read_Request (Path : String) return Request
   is
      Input : aliased Files.Lease_Streams.Input_Stream;
      Work : Request;
   begin
      if Files.Lease_Streams.Open (Path, Input) /=
          Hostkit.Lease_Files.Opened
        or else Files.Lease_Streams.Size (Input) >
          Long_Long_Integer (Files.Job_Records.Max_Transport_Bytes)
      then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      if Files.Job_Records.Read_String
        (Input'Access, Request_Header'Length) /= Request_Header
      then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      Work.Kind := Operation_Kind'Input (Input'Access);
      Work.Root := To_Unbounded_String
        (Files.Job_Records.Read_String
           (Input'Access, Files.Job_Records.Max_Path_Length));
      Work.Recent := Boolean'Input (Input'Access);
      Work.Query := To_Unbounded_String
        (Files.Job_Records.Read_String
           (Input'Access, Files.Job_Records.Max_Text_Length));
      Work.Selected := Files.Job_Records.Read_Items (Input'Access);
      Work.Settings := Files.Job_Records.Read_Settings (Input'Access);
      Work.Context_Revision := Natural'Input (Input'Access);
      Work.View_Incarnation := Natural'Input (Input'Access);
      if not Files.Lease_Streams.End_Of_Stream (Input) then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      if not Request_Path_Is_Consistent
        (To_String (Work.Root), Work.Recent)
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

   procedure Write_Outcome
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Done : Outcome)
   is
   begin
      String'Output (Stream, Result_Header);
      Operation_Kind'Output (Stream, Done.Kind);
      Boolean'Output (Stream, Done.Recent);
      Files.Job_Records.Write_Operation_Result (Stream, Done.Result);
      Files.Job_Records.Write_Items (Stream, Done.Items);
      Files.Job_Records.Write_String
        (Stream, To_String (Done.Selection), Files.Job_Records.Max_Path_Length);
      Files.Job_Records.Write_String
        (Stream, To_String (Done.Visible_Error),
         Files.Job_Records.Max_Error_Length);
      Files.Job_Records.Write_Signature (Stream, Done.Signature);
      Write_Paths (Stream, Done.Moved_From);
      Write_Paths (Stream, Done.Moved_To);
   end Write_Outcome;

   function Read_Outcome (Path : String) return Outcome
   is
      Input : aliased Files.Lease_Streams.Input_Stream;
      Done : Outcome;
   begin
      if Files.Lease_Streams.Open (Path, Input) /=
          Hostkit.Lease_Files.Opened
        or else Files.Lease_Streams.Size (Input) >
          Long_Long_Integer (Files.Job_Records.Max_Transport_Bytes)
      then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      if Files.Job_Records.Read_String
        (Input'Access, Result_Header'Length) /= Result_Header
      then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      Done.Kind := Operation_Kind'Input (Input'Access);
      Done.Recent := Boolean'Input (Input'Access);
      Done.Result := Files.Job_Records.Read_Operation_Result (Input'Access);
      Done.Items := Files.Job_Records.Read_Items (Input'Access);
      Done.Selection := To_Unbounded_String
        (Files.Job_Records.Read_String
           (Input'Access, Files.Job_Records.Max_Path_Length));
      Done.Visible_Error := To_Unbounded_String
        (Files.Job_Records.Read_String
           (Input'Access, Files.Job_Records.Max_Error_Length));
      Done.Signature := Files.Job_Records.Read_Signature (Input'Access);
      Done.Moved_From := Read_Paths (Input'Access);
      Done.Moved_To := Read_Paths (Input'Access);
      if Natural (Done.Moved_From.Length) /= Natural (Done.Moved_To.Length) then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      if not Files.Lease_Streams.End_Of_Stream (Input) then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      Files.Lease_Streams.Release (Input);
      return Done;
   exception
      when others =>
         Files.Lease_Streams.Release (Input);
         raise;
   end Read_Outcome;

   function Start
     (Model : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Kind : Operation_Kind) return Files.Operations.Operation_Result
   is
      Job  : Files.Process_Jobs.Session;
      File : aliased Files.Exclusive_Streams.Output_Stream;
      Work : Request :=
        (Kind => Kind, Root => To_Unbounded_String (Files.Model.Current_Path (Model)),
         Recent => Files.Model.In_Recent_View (Model), Query => To_Unbounded_String (Files.Model.Filter_Text (Model)),
         Selected => Files.Model.Selected_Items (Model), Settings => Settings,
         Context_Revision => 0,
         View_Incarnation => Files.Model.View_Incarnation (Model));
      Actions : Files.Paste.Resolved_Action_Vectors.Vector;
   begin
      if Files.Model.Paste_Execution_Is_Active (Model) or else Files.Model.Paste_Conflict_Is_Active (Model) then
         return (Status => Files.Operations.Operation_Disabled, others => <>);
      end if;
      if Kind in Search_Names | Search_Contents and then Length (Work.Query) = 0 then
         Files.Model.Set_Error (Model, "error.filter.empty");
         return (Status => Files.Operations.Operation_Disabled,
                 Error_Key => To_Unbounded_String ("error.filter.empty"), others => <>);
      end if;
      if (Kind = Undo and then Files.Model.Undo_History (Model).Is_Empty)
        or else (Kind = Redo and then Files.Model.Redo_History (Model).Is_Empty)
      then
         Files.Model.Set_Error (Model, "error.undo.failed");
         return (Status => Files.Operations.Operation_Failed,
                 Error_Key => To_Unbounded_String ("error.undo.failed"), others => <>);
      end if;
      if Kind not in Search_Names | Search_Contents | Undo | Redo | Empty_Trash
        and then (Work.Selected.Is_Empty or else Files.Model.Selection_Includes_Temporary (Model))
      then
         declare
            Key : constant String :=
              (case Kind is
                  when Duplicate => "error.duplicate.failed",
                  when Compress_Zip | Compress_Seven_Zip => "error.compress.failed",
                  when Extract => "error.extract.failed",
                  when Trash | Delete_Permanently | Restore => "error.selection.empty",
                  when others => "error.search.failed");
         begin
            Files.Model.Set_Error (Model, Key);
            return (Status => Files.Operations.Operation_Failed, Error_Key => To_Unbounded_String (Key), others => <>);
         end;
      end if;
      --  Clearing an earlier diagnostic is itself listing-visible state. Capture
      --  the operation generation afterwards so ordinary startup does not make
      --  its own result stale, while later listing changes still do.
      Files.Model.Set_Error (Model, "");
      Work.Context_Revision := Files.Model.Listing_Revision (Model);
      Files.Process_Jobs.Reserve (Job);
      Files.History_Journal.Save_Stacks
        (Files.Process_Jobs.Path (Job, ""), Files.Model.Undo_History (Model),
         Files.Model.Redo_History (Model), Required => True);
      Files.Exclusive_Streams.Create
        (File, Files.Process_Jobs.Path (Job, "request"));
      Write_Request (File'Access, Work);
      Files.Job_Records.Validate_Size (Files.Exclusive_Streams.Size (File));
      Files.Exclusive_Streams.Close (File);
      Files.Process_Jobs.Launch (Job, "--files-operation");
      Actions.Append
        (Files.Paste.Resolved_Action'
           (Source_Path => Work.Root, Dest_Path => Work.Root, Skip => False, Replaced => False));
      Files.Model.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Copy, Clear_Clipboard => False);
      Files.Model.Set_Background_Operation
        (Model, Job,
         (case Kind is
             when Duplicate => "command.file.duplicate",
             when Compress_Zip => "command.file.compress_zip",
             when Compress_Seven_Zip => "command.file.compress_7z",
             when Extract => "command.file.extract",
             when Search_Names => "command.directory.search_recursive",
             when Search_Contents => "command.search.contents",
             when Trash => "command.file.delete",
             when Delete_Permanently => "command.file.delete_permanently",
             when Restore => "command.trash.restore",
             when Empty_Trash => "command.trash.empty",
             when Undo => "command.edit.undo",
             when Redo => "command.edit.redo"));
      return (Status => Files.Operations.Operation_Success, Path => Work.Root, others => <>);
   exception
      when others =>
         Files.Exclusive_Streams.Close_Safely (File);
         Files.Process_Jobs.Reset (Job);
         Files.Model.Set_Error (Model, "error.drop.failed");
         return (Status => Files.Operations.Operation_Failed,
                 Error_Key => To_Unbounded_String ("error.drop.failed"), others => <>);
   end Start;

   function Advance
     (Model : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model) return Files.Operations.Operation_Result
   is
      Job       : constant Files.Process_Jobs.Session := Files.Model.Background_Operation (Model);
      Finished  : Boolean;
      Cancelled : Boolean := False;
      Done      : Outcome;
      Work      : Request;
      Same_View       : Boolean := False;
      Context_Matches : Boolean := False;
      Reload_Owed     : Boolean := False;
      --  Whether the failure handler could read which operation this was.
      Known_Kind      : Boolean := False;

      function Failed_Key return String is
        (if Known_Kind then Failure_Key (Work.Kind) else "error.operation.failed");

      --  The view the job started from is still on screen: no navigation since
      --  (not even away and back), so it may refresh that view and report its
      --  diagnostic there even though edits in the view moved its revision.
      function Matches_Current_View
        (Candidate : Request)
         return Boolean is
        (Candidate.Root = Files.Model.Current_Path (Model)
         and then Candidate.Recent = Files.Model.In_Recent_View (Model)
         and then Files.Settings.Same_Content (Candidate.Settings, Settings)
         and then Candidate.View_Incarnation = Files.Model.View_Incarnation (Model));

      --  Additionally nothing listing-visible changed since the job started,
      --  so its directory snapshot can replace the items directly.
      function Matches_Current_Context
        (Candidate : Request)
         return Boolean is
        (Matches_Current_View (Candidate)
         and then Candidate.Context_Revision =
           Files.Model.Listing_Revision (Model));

      procedure Reload_Current_View (Select_Name : String := "") is
         Reload : constant Files.Operations.Operation_Result :=
           Files.Refresh_Jobs.Start (Model, Settings, True, Select_Name);
         pragma Unreferenced (Reload);
      begin
         null;
      end Reload_Current_View;

      procedure Recover_Undo is
         Destinations, Sources, Identities, Tree_Revisions : Files.Types.String_Vectors.Vector;
         Untracked, Untracked_Identities, Untracked_Tree_Revisions : Files.Types.String_Vectors.Vector;
         Undo_Stack : constant Files.Model.Undo_Entry_Vectors.Vector := Files.Model.Undo_History (Model);
         Redo_Stack : Files.Model.Undo_Entry_Vectors.Vector := Files.Model.Redo_History (Model);
         --  Every path the undo history already records as created.
         Recorded : Files.Settings.Path_Sets.Set;
      begin
         Work := Read_Request (Files.Process_Jobs.Path (Job, "request"));
         Files.Job_Context.Read_Created
           (Files.Process_Jobs.Path (Job, ""), Destinations, Sources, Identities, Tree_Revisions);
         if Work.Kind = Redo and then not Redo_Stack.Is_Empty then
            declare
               Action : Files.Model.Undo_Entry := Redo_Stack.Last_Element;
               --  Each destination's place in From, and what is completed:
               --  looked up per created entry, not scanned for.
               Places    : Index_Maps.Map;
               Completed : Files.Settings.Path_Sets.Set;
            begin
               for Index in Action.From.First_Index .. Action.From.Last_Index loop
                  if not Places.Contains (To_String (Action.From (Index))) then
                     Places.Insert (To_String (Action.From (Index)), Index);
                  end if;
               end loop;
               for Path of Action.Forward_Completed loop
                  Completed.Include (To_String (Path));
               end loop;
               for Created_Index in Destinations.First_Index .. Destinations.Last_Index loop
                  declare
                     Dest : constant String := To_String (Destinations (Created_Index));
                  begin
                     if Places.Contains (Dest) and then not Completed.Contains (Dest) then
                        declare
                           Index : constant Positive := Places.Element (Dest);
                        begin
                           while Action.Created_Identities.Last_Index < Index loop
                              Action.Created_Identities.Append (Null_Unbounded_String);
                           end loop;
                           Action.Created_Identities.Replace_Element
                             (Index, Identities (Created_Index));
                           while Action.Created_Tree_Revisions.Last_Index < Index loop
                              Action.Created_Tree_Revisions.Append (Null_Unbounded_String);
                           end loop;
                           Action.Created_Tree_Revisions.Replace_Element
                             (Index, Tree_Revisions (Created_Index));
                        end;
                        Action.Forward_Completed.Append (Destinations (Created_Index));
                        Completed.Include (Dest);
                     end if;
                  end;
               end loop;
               Redo_Stack.Replace_Element (Redo_Stack.Last_Index, Action);
               Files.Model.Set_History (Model, Undo_Stack, Redo_Stack);
            end;
         elsif Work.Kind in Duplicate | Compress_Zip | Compress_Seven_Zip | Extract then
            for Action of Undo_Stack loop
               for Path of Action.From loop
                  Recorded.Include (To_String (Path));
               end loop;
            end loop;
            for Index in Destinations.First_Index .. Destinations.Last_Index loop
               if not Recorded.Contains (To_String (Destinations (Index))) then
                  Untracked.Append (Destinations (Index));
                  Untracked_Identities.Append (Identities (Index));
                  Untracked_Tree_Revisions.Append (Tree_Revisions (Index));
               end if;
            end loop;
            if not Untracked.Is_Empty then
               Files.Operations.Record_Undo
                 (Model, Files.Model.Undo_Delete_Created, Untracked,
                  Files.Types.String_Vectors.Empty_Vector, Redoable => False,
                  Original_Identities => Untracked_Identities,
                  Original_Tree_Revisions => Untracked_Tree_Revisions,
                  Retain_Verified_Main => Natural (Untracked.Length));
            end if;
         end if;
      exception
         when Swallowed : others =>
            Files.Diagnostics.Note (Swallowed, "Files.Operation_Jobs");
      end Recover_Undo;
   begin
      Files.Process_Jobs.Poll (Job, Finished, Cancelled);
      if not Finished then
         return (Status => Files.Operations.Operation_Success, others => <>);
      end if;
      Done := Read_Outcome (Files.Process_Jobs.Path (Job, "result"));
      Work := Read_Request (Files.Process_Jobs.Path (Job, "request"));
      if Done.Kind /= Work.Kind or else Done.Recent /= Work.Recent then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      --  What the helper renamed, moved or removed did happen, whatever the
      --  window shows now: labels and favorites follow it.
      for Index in Done.Moved_From.First_Index .. Done.Moved_From.Last_Index loop
         if Length (Done.Moved_To (Index)) = 0 then
            Files.Model.Note_Path_Removed (Model, To_String (Done.Moved_From (Index)));
         else
            Files.Model.Note_Path_Move
              (Model, To_String (Done.Moved_From (Index)), To_String (Done.Moved_To (Index)));
         end if;
      end loop;
      if not Files.History_Journal.Restore
        (Files.Process_Jobs.Path (Job, ""), Model)
      then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      Same_View := Matches_Current_View (Work);
      Context_Matches := Matches_Current_Context (Work);
      if Done.Kind in Search_Names | Search_Contents then
         if not Context_Matches
           or else Work.Query /= Files.Model.Filter_Text (Model)
         then
            Files.Model.Clear_Paste_Execution (Model);
            return (Status => Files.Operations.Operation_Success, others => <>);
         end if;
      end if;
      Files.Model.Clear_Paste_Execution (Model);
      if Done.Result.Status /= Files.Operations.Operation_Success then
         Recover_Undo;
      end if;
      if Done.Kind in Trash | Delete_Permanently | Restore | Empty_Trash | Undo | Redo
        or else (Done.Kind in Duplicate | Compress_Zip | Compress_Seven_Zip | Extract
                 and then (Cancelled or else Done.Result.Status /= Files.Operations.Operation_Success))
      then
         if Same_View then
            --  Finalize error/history before the refresh captures this
            --  revision. A result from an older view must not refresh or alter
            --  the diagnostic of the view now displayed, but an edit within the
            --  same view must not cost it the reload either.
            Files.Model.Set_Error
              (Model, (if Cancelled then "" else To_String (Done.Visible_Error)));
            Reload_Current_View;
         end if;
         return (if Cancelled then (Status => Files.Operations.Operation_Success, others => <>) else Done.Result);
      end if;
      if not Cancelled
        and then Done.Result.Status = Files.Operations.Operation_Success
        and then Context_Matches
      then
         if Done.Recent then
            Files.Model.Navigate_Recent (Model, Done.Items);
         else
            Files.Model.Replace_Items (Model, Done.Items);
         end if;
         Files.Model.Set_Directory_Signature (Model, Done.Signature);
         if Done.Kind in Search_Names | Search_Contents then
            Files.Model.Note_Search_Results
              (Model, (if Done.Kind = Search_Names then Files.Types.Search_Names else Files.Types.Search_Contents));
         else
            Files.Model.Clear_Search_Results (Model);
            if Length (Done.Selection) > 0 then
               declare
                  Selected : constant Boolean := Files.Model.Select_By_Name (Model, To_String (Done.Selection));
                  pragma Unreferenced (Selected);
               begin
                  null;
               end;
            end if;
         end if;
      elsif not Cancelled
        and then Done.Result.Status = Files.Operations.Operation_Success
        and then Same_View
        and then Done.Kind not in Search_Names | Search_Contents
      then
         --  Same view, but its snapshot predates a later listing change:
         --  reread it rather than leave the operation's new entries unlisted.
         --  Started below, once the diagnostic it must preserve is final.
         Reload_Owed := True;
      end if;
      if not Same_View then
         --  The filesystem work and restored history remain valid, but its
         --  directory snapshot and diagnostic belong to the view it started
         --  from, not the one now displayed -- even when it was cancelled.
         return (if Cancelled then (Status => Files.Operations.Operation_Success, others => <>)
                 else Done.Result);
      end if;
      if Cancelled then
         Files.Model.Set_Error (Model, "");
         return (Status => Files.Operations.Operation_Success, others => <>);
      end if;
      Files.Model.Set_Error (Model, To_String (Done.Visible_Error));
      if Reload_Owed then
         Reload_Current_View (To_String (Done.Selection));
      end if;
      Files.Operations.Ensure_Selected_Item_Extra (Model);
      return Done.Result;
   exception
      when others =>
         --  Outcome decoding can fail before the request was read. Recover its
         --  identity independently so a same-view mutation is still reloaded,
         --  while an old job cannot disturb a newer view.
         begin
            Work := Read_Request (Files.Process_Jobs.Path (Job, "request"));
            Same_View := Matches_Current_View (Work);
            Known_Kind := True;
         exception
            when others =>
               Same_View := False;
         end;
         Files.Model.Clear_Paste_Execution (Model);
         declare
            Restored : constant Boolean :=
              Files.History_Journal.Restore (Files.Process_Jobs.Path (Job, ""), Model);
            pragma Unreferenced (Restored);
         begin
            null;
         end;
         Recover_Undo;
         --  Even an interrupted destructive operation may have changed its
         --  original view, but it must not refresh a different current view.
         if Same_View then
            Files.Model.Set_Error
              (Model, (if Cancelled then "" else Failed_Key));
            Reload_Current_View;
         end if;
         if Cancelled then
            return (Status => Files.Operations.Operation_Success, others => <>);
         end if;
         return (Status => Files.Operations.Operation_Failed,
                 Error_Key => To_Unbounded_String (Failed_Key), others => <>);
   end Advance;

   procedure Run_Helper (Directory : String) is
      File  : aliased Files.Exclusive_Streams.Output_Stream;
      Work  : Request;
      Done  : Outcome;
      Model : Files.Model.Window_Model;
   begin
      Work := Read_Request (Hostkit.Fs.Join (Directory, "request"));
      Done.Kind := Work.Kind;
      Files.Model.Initialize (Model, To_String (Work.Root), Work.Selected, Hostkit.Fs.Home_Directory);
      if Work.Recent then
         Files.Model.Navigate_Recent (Model, Work.Selected);
      end if;
      if not Files.History_Journal.Restore (Directory, Model) then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      Files.History_Journal.Save (Model, Required => Work.Kind in Trash | Undo | Redo);
      if Work.Kind in Search_Names | Search_Contents then
         Files.Model.Set_Filter (Model, To_String (Work.Query));
      else
         Files.Model.Select_All_Visible (Model);
      end if;
      Done.Result :=
        (case Work.Kind is
            when Duplicate => Files.Operations.Duplicate_Selected (Model, Work.Settings),
            when Compress_Zip =>
              Files.Operations.Compress_Selected (Model, Work.Settings, Files.Operations.Zip_Archive),
            when Compress_Seven_Zip =>
              Files.Operations.Compress_Selected (Model, Work.Settings, Files.Operations.Seven_Zip_Archive),
            when Extract => Files.Operations.Extract_Selected (Model, Work.Settings),
            when Search_Names => Files.Operations.Run_Recursive_Search (Model, Work.Settings),
            when Search_Contents => Files.Operations.Run_Content_Search (Model, Work.Settings),
            when Trash => Files.Operations.Delete_Selected (Model, Work.Settings),
            when Delete_Permanently => Files.Operations.Delete_Selected_Permanently (Model, Work.Settings),
            when Restore => Files.Operations.Restore_Selected_From_Trash (Model, Work.Settings),
            when Empty_Trash => Files.Operations.Empty_Trash (Model, Work.Settings),
            when Undo => Files.Operations.Undo_Last (Model, Work.Settings),
            when Redo => Files.Operations.Redo_Last (Model, Work.Settings));
      Files.History_Journal.Save (Model);
      Done.Visible_Error := To_Unbounded_String
        (if Files.Model.Last_Error_Key (Model) = "" then To_String (Done.Result.Error_Key)
         else Files.Model.Last_Error_Key (Model));
      Done.Recent := Files.Model.In_Recent_View (Model);
      Done.Selection := To_Unbounded_String (Files.Model.Selected_Name (Model));
      for Row of Files.Model.Visible_Rows (Model) loop
         Done.Items.Append (Row.Item);
      end loop;
      Done.Signature := Files.Model.Directory_Signature_Of (Model);
      Files.Model.Take_Path_Moves (Model, Done.Moved_From, Done.Moved_To);
      Files.Exclusive_Streams.Create
        (File, Hostkit.Fs.Join (Directory, "result.tmp"));
      Write_Outcome (File'Access, Done);
      Files.Job_Records.Validate_Size (Files.Exclusive_Streams.Size (File));
      Files.Exclusive_Streams.Close (File);
      declare
         Step    : Files.Durable_Writes.Publication_Step;
         Outcome : constant Files.Durable_Writes.Publication_Result :=
           Files.Durable_Writes.Publish
             (Hostkit.Fs.Join (Directory, "result.tmp"), Hostkit.Fs.Join (Directory, "result"), Step);

         function State (Path : String) return String is
           (if Ada.Directories.Exists (Path) then "present" else "gone");
      begin
         if not Files.Durable_Writes.Published (Outcome) then
            --  Say which part failed, as a machine-readable diagnostic: an
            --  intermittent CI failure here could not be reproduced locally.
            raise Ada.Directories.Use_Error with
              "publish=" & Files.Durable_Writes.Publication_Result'Image (Outcome)
              & ";step=" & Files.Durable_Writes.Publication_Step'Image (Step)
              & ";dir=" & State (Directory)
              & ";tmp=" & State (Hostkit.Fs.Join (Directory, "result.tmp"))
              & ";result=" & State (Hostkit.Fs.Join (Directory, "result"));
         end if;
      end;
   exception
      when others =>
         Files.Exclusive_Streams.Close_Safely (File);
         raise;
   end Run_Helper;
end Files.Operation_Jobs;
