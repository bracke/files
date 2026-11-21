with Files.Jobs.Context;
with Ada.Directories;
with Files.Operations.Undo_Recording;
with Files.Window_Polls;
with Files.Diagnostics;
with Hostkit.Process;

with Files.File_System;
with Files.Undo.Journal;
with Files.Timing;
with Files.Refresh;
with Files.IO.Fs_Primitives;
with Files.Leaf_Names;
with Hostkit.Fs;
with Files.Model.History;
with Files.Model.Selection;
with Files.Settings.Open_Actions;

package body Files.Operations.Support is
   use Ada.Strings.Unbounded;

   function First_Free_Leaf
     (Directory : String;
      Base      : String;
      Extension : String;
      Marker    : not null access function (Attempt : Natural) return String;
      First     : Natural := 1)
      return String
   is
      --  Asked once: the search may try thousands of names.
      Limit : constant Hostkit.Fs.Leaf_Name_Limit := Hostkit.Fs.Leaf_Name_Limit_At (Directory);

      --  A name the host will not answer for raises (Is_Taken): never
      --  handed out as free.
      function Taken (Leaf : String) return Boolean is
        (Files.IO.Fs_Primitives.Is_Taken (Hostkit.Fs.Join (Directory, Leaf)));

      Free : constant String :=
        Files.Leaf_Names.First_Free (Base, Extension, Marker, Taken'Access, Limit, First);
   begin
      if Free = "" then
         raise Ada.Directories.Use_Error with "no_free_name=" & Directory;
      end if;
      return Free;
   end First_Free_Leaf;

   function Empty_Action return Files.Settings.Open_Action is
   begin
      return Files.Settings.Open_Actions.Make_Action ("", Files.Settings.String_Vectors.Empty_Vector);
   end Empty_Action;

   function Make_Result
     (Status      : Operation_Status;
      Error_Key   : String := "";
      Path        : String := "";
      Action      : Files.Settings.Open_Action := Empty_Action;
      Attempted   : Boolean := False;
      Found       : Boolean := False;
      Exit_Known  : Boolean := False;
      Exit_Status : Integer := 0)
      return Operation_Result is
   begin
      return
        (Status    => Status,
         Error_Key => To_Unbounded_String (Error_Key),
         Path      => To_Unbounded_String (Path),
         Action    => Action,
         Execution =>
           (Attempted         => Attempted,
            Executable_Found  => Found,
            Exit_Status_Known => Exit_Known,
            Exit_Status       => Exit_Status));
   end Make_Result;

   function Disabled
     (Model     : in out Files.Model.Window_Model;
      Error_Key : String)
      return Operation_Result is
   begin
      Files.Model.Set_Error (Model, Error_Key);
      return Make_Result (Operation_Disabled, Error_Key);
   end Disabled;

   function Executable_Is_Available
     (Executable : String)
      return Boolean is (Hostkit.Process.Is_Runnable (Executable));

   function Reload_Current_Directory
     (Model       : in out Files.Model.Window_Model;
      Settings    : Files.Settings.Settings_Model;
      Select_Name : String := "";
      Preserve_Selection : Boolean := False)
      return Operation_Result
   is
   begin
      if Files.Model.Background_Transfers (Model) then
         return Files.Refresh.Start (Model, Settings, Force => True, Select_Name => Select_Name);
      end if;
      Reload_In_Place :
      declare
         --  Only a reload here restores them: the background one above
         --  restores its own, so a Select All is not copied for nothing.
         Previous_Selection : constant Files.Items.Item_Vectors.Vector :=
           Files.Model.Selection.Selected_Items (Model);
         Previous_Primary : constant String :=
           To_String (Files.Model.Selection.Selected_Item (Model).Full_Path);
      begin
         --  The Recent view has no backing directory (Current_Path is empty), so a
         --  directory load would spuriously fail and a mutation performed from
         --  Recent would be reported as failed with the view left stale. Rebuild it
         --  from the recorded recent paths instead (Load_Recent_Items).
         if Files.Model.In_Recent_View (Model) then
            Files.Model.Navigate_Recent (Model, Files.File_System.Load_Recent_Items (Settings));
            if Preserve_Selection and then Select_Name = "" then
               Files.Model.Selection.Restore
                 (Model, Previous_Selection, Previous_Primary);
            end if;
            Files.Model.Set_Error (Model, "");
            return Make_Result (Operation_Success);
         end if;

         declare
            Load : constant Files.File_System.Directory_Load_Result :=
              Files.File_System.Load_Directory_Deferring_Thumbnails (Files.Model.Current_Path (Model), Settings);
         begin
            if not Load.Success then
               Files.Model.Set_Error (Model, To_String (Load.Error_Key));
               return
                 Make_Result (Operation_Failed, To_String (Load.Error_Key), Files.Model.Current_Path (Model));
            end if;

            Files.Model.Replace_Items (Model, Load.Items);
            Files.Model.Set_Directory_Signature (Model, Load.Signature);
            if Select_Name /= "" then
               declare
                  Selection_Restored : constant Boolean := Files.Model.Selection.Select_By_Name (Model, Select_Name);
                  pragma Unreferenced (Selection_Restored);
               begin
                  null;
               end;
            elsif Preserve_Selection then
               Files.Model.Selection.Restore
                 (Model, Previous_Selection, Previous_Primary);
            end if;
            Files.Model.Set_Error (Model, "");
            Files.Window_Polls.Ensure_Selected_Item_Extra (Model, Settings.Show_Hidden_Files);
            --  A reload runs after every operation, so it must not decode each
            --  new image in the folder while the UI waits: as on navigation, the
            --  missing thumbnails are left to a background listing, which the
            --  window's next poll launches.
            if Files.File_System.Thumbnails_Missing (Load.Items) then
               Files.Model.Note_Owed_Refresh (Model, Force => True, Select_Name => "");
            end if;
            return Make_Result (Operation_Success, Path => Files.Model.Current_Path (Model));
         end;
      end Reload_In_Place;
   end Reload_Current_Directory;

   function Batch_Failed
     (Model      : in out Files.Model.Window_Model;
      Settings   : Files.Settings.Settings_Model;
      Error_Key  : String;
      Directory  : String;
      Wrote_Some : Boolean)
      return Operation_Result is
   begin
      if Wrote_Some then
         Reload_With_Error (Model, Settings, Error_Key);
      else
         Files.Model.Set_Error (Model, Error_Key);
      end if;
      return Make_Result (Operation_Failed, Error_Key, Directory);
   exception
      when Failure : others =>
         Files.Diagnostics.Note (Failure, "Files.Operations.Support");
         Files.Model.Set_Error (Model, Error_Key);
         return Make_Result (Operation_Failed, Error_Key, Directory);
   end Batch_Failed;

   procedure Reload_With_Error
     (Model : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Error_Key : String;
      Path : String := "")
   is
      Reload : Operation_Result;
      pragma Unreferenced (Reload);
   begin
      --  Set before the reload is scheduled (a background one keeps it) and
      --  again after one done here, which clears the error it finds.
      Files.Model.Set_Error (Model, Error_Key, Path);
      Reload := Reload_Current_Directory (Model, Settings);
      if not Files.Model.Background_Transfers (Model) then
         Files.Model.Set_Error (Model, Error_Key, Path);
      end if;
   end Reload_With_Error;

   procedure Generate_Missing_Thumbnails
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Items    : Files.Items.Item_Vectors.Vector) is
   begin
      if Files.File_System.Thumbnails_Missing (Items) then
         declare
            Started : constant Operation_Result := Files.Refresh.Start (Model, Settings, Force => True);
            pragma Unreferenced (Started);
         begin
            null;
         end;
      end if;
   end Generate_Missing_Thumbnails;

   --  How long Checkpoint_Undo leaves between records.
   Checkpoint_Interval : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Seconds (1);

   --  The throttle's clock: the test suite's when it set one.
   function Checkpoint_Now return Ada.Real_Time.Time is
      Hook : constant Clock_Hook := Checkpoint_Clock;
   begin
      return (if Hook = null then Ada.Real_Time.Clock else Hook.all);
   end Checkpoint_Now;

   --  Replace the batch's entry with one covering every item appended.
   --  Now is the throttle's clock reading the record is made at.
   procedure Record_Progress
     (Model    : in out Files.Model.Window_Model;
      Progress : in out Progressive_Undo;
      Now      : Ada.Real_Time.Time)
   is
      Previous : Files.Undo.History.Undo_Entry;
      Found    : Boolean;
   begin
      if Progress.Recorded then
         Files.Model.History.Take_Undo (Model, Previous, Found);
         --  Taken: should the record below raise, a later one must not
         --  take the entry under it, which is not the batch's.
         Progress.Recorded := False;
      end if;
      --  Counted before the record, which may raise: a failed attempt is
      --  not retried until the next interval either.
      Progress.Attempted := True;
      Progress.Attempted_Count := Natural (Progress.Items.Length);
      Progress.Last_Checkpoint := Now;
      Progress.Recorded := Files.Operations.Undo_Recording.Try_Record_Undo
        (Model, Progress.Kind, Progress.Items,
         Create_Kind => Progress.Create_Kind,
         Redoable    => Progress.Redoable);
      --  Every item a record admitted was verified then: a later checkpoint
      --  trusts it, though its path has since been reused.
      if Progress.Recorded
        and then Natural (Files.Model.History.Undo_From_Paths (Model).Length) = Natural (Progress.Items.Length)
      then
         for Item of Progress.Items loop
            Item.Provenance := Files.Undo.History.Verified;
         end loop;
      end if;
      if Progress.Durable then
         Files.Undo.Journal.Save (Files.Model.History.State (Model), Mode => Files.Undo.Journal.Must_Commit);
      end if;
   end Record_Progress;

   procedure Checkpoint_Undo
     (Model    : in out Files.Model.Window_Model;
      Progress : in out Progressive_Undo)
   is
      --  Read once a call, whether or not it records, so a test clock
      --  counts one reading per item.
      Now : constant Ada.Real_Time.Time := Checkpoint_Now;
   begin
      if not Progress.Attempted
        or else Files.Timing.Elapsed (Now, Progress.Last_Checkpoint, Checkpoint_Interval)
      then
         Record_Progress (Model, Progress, Now);
      end if;
   end Checkpoint_Undo;

   function Finish_Undo
     (Model    : in out Files.Model.Window_Model;
      Progress : in out Progressive_Undo) return Undo_Outcome is
   begin
      if Natural (Progress.Items.Length) /= Progress.Attempted_Count then
         Record_Progress (Model, Progress, Checkpoint_Now);
      end if;
      return (if Progress.Items.Is_Empty or else Progress.Recorded then Undo_Covered else Undo_Unavailable);
   end Finish_Undo;

   procedure Note_Undo_Outcome
     (Model   : in out Files.Model.Window_Model;
      Outcome : Undo_Outcome;
      Result  : Operation_Result) is
   begin
      if Outcome = Undo_Unavailable and then Result.Status = Operation_Success then
         Files.Model.Set_Error (Model, Undo_Unavailable_Notice);
      end if;
   end Note_Undo_Outcome;

   procedure Finish_Failed_Undo
     (Model    : in out Files.Model.Window_Model;
      Progress : in out Progressive_Undo) is
   begin
      declare
         --  The batch's own failure is reported; a missing Undo is no news.
         Outcome : constant Undo_Outcome := Finish_Undo (Model, Progress);
         pragma Unreferenced (Outcome);
      begin
         null;
      end;
   exception
      when Unrecorded : others =>
         Files.Diagnostics.Note (Unrecorded, "Files.Operations.Support");
   end Finish_Failed_Undo;

   function Publish_Staged
     (Staged   : String;
      Target   : String;
      Identity : out Ada.Strings.Unbounded.Unbounded_String;
      Revision : out Ada.Strings.Unbounded.Unbounded_String)
      return Boolean renames Files.File_System.Publish_Staged;

   procedure Discard_Stage (Stage : String) is
   begin
      if not Files.Jobs.Context.Discard_Stage (Stage) then
         Files.Diagnostics.Trace ("Files.Operations", "stage_discard_failed=" & Stage);
      end if;
   end Discard_Stage;

end Files.Operations.Support;
