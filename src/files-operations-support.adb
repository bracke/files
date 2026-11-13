with Files.Diagnostics;
with Hostkit.Process;
with Ada.Strings.Unbounded;

with Files.File_System;
with Files.History_Journal;
with Files.Timing;
with Files.Refresh_Jobs;
with Files.Fs_Primitives;
with Files.Leaf_Names;
with Hostkit.Fs;

package body Files.Operations.Support is
   use Ada.Strings.Unbounded;

   function First_Free_Name
     (Directory : String;
      Base      : String;
      Extension : String;
      Marker    : not null access function (Attempt : Natural) return String;
      First     : Natural := 1)
      return String
   is
      Dos_Rules : constant Boolean := Hostkit.Fs.Uses_Dos_Filename_Rules (Directory);
      Dotted    : constant Natural :=
        (if Extension = "" then 0 else Files.Leaf_Names.Length_Under ("." & Extension, Dos_Rules));

      function Name (Attempt : Natural) return String is
        (Files.Leaf_Names.Cut
           (Base, Marker (Attempt),
            (if Dotted >= Files.Leaf_Names.Max_Length then 0 else Files.Leaf_Names.Max_Length - Dotted),
            Dos_Rules));
   begin
      for Attempt in First .. Max_Name_Attempts loop
         if not Exists_Safely (Files.Fs_Primitives.Compose_Text (Directory, Name (Attempt), Extension)) then
            return Name (Attempt);
         end if;
      end loop;
      return Name (First);
   end First_Free_Name;

   function Empty_Action return Files.Settings.Open_Action is
   begin
      return Files.Settings.Make_Action ("", Files.Settings.String_Vectors.Empty_Vector);
   end Empty_Action;

   function Exists_Safely (Path : String) return Boolean renames Files.Fs_Primitives.Entry_Exists;

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
         return Files.Refresh_Jobs.Start (Model, Settings, Force => True, Select_Name => Select_Name);
      end if;
      Reload_In_Place :
      declare
         --  Only a reload here restores them: the background one above
         --  restores its own, so a Select All is not copied for nothing.
         Previous_Selection : constant Files.Items.Item_Vectors.Vector :=
           Files.Model.Selected_Items (Model);
         Previous_Primary : constant String :=
           To_String (Files.Model.Selected_Item (Model).Full_Path);
      begin
         --  The Recent view has no backing directory (Current_Path is empty), so a
         --  directory load would spuriously fail and a mutation performed from
         --  Recent would be reported as failed with the view left stale. Rebuild it
         --  from the recorded recent paths instead, dropping any that no longer
         --  resolve. Mirrors Navigation.Navigate_Recent, which this lower-level
         --  shared helper cannot call.
         if Files.Model.In_Recent_View (Model) then
            declare
               Recent : constant Files.Types.String_Vectors.Vector :=
                 Files.Settings.Recent_Paths (Settings);
               Items  : Files.Items.Item_Vectors.Vector;
            begin
               for Path of Recent loop
                  declare
                     Loaded : constant Files.File_System.Item_Load_Result :=
                       Files.File_System.Load_Item (To_String (Path), Settings);
                  begin
                     if Loaded.Success then
                        Items.Append (Loaded.Item);
                     end if;
                  end;
               end loop;
               Files.Model.Navigate_Recent (Model, Items);
               if Preserve_Selection and then Select_Name = "" then
                  Files.Model.Restore_Selection
                    (Model, Previous_Selection, Previous_Primary);
               end if;
               Files.Model.Set_Error (Model, "");
            end;
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
                  Selection_Restored : constant Boolean := Files.Model.Select_By_Name (Model, Select_Name);
                  pragma Unreferenced (Selection_Restored);
               begin
                  null;
               end;
            elsif Preserve_Selection then
               Files.Model.Restore_Selection
                 (Model, Previous_Selection, Previous_Primary);
            end if;
            Files.Model.Set_Error (Model, "");
            Files.Operations.Ensure_Selected_Item_Extra (Model);
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
            Started : constant Operation_Result := Files.Refresh_Jobs.Start (Model, Settings, Force => True);
            pragma Unreferenced (Started);
         begin
            null;
         end;
      end if;
   end Generate_Missing_Thumbnails;

   --  How long Checkpoint_Undo leaves between records.
   Checkpoint_Interval : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Seconds (1);

   --  Replace the batch's entry with one covering every item appended.
   procedure Record_Progress
     (Model    : in out Files.Model.Window_Model;
      Progress : in out Progressive_Undo)
   is
      Previous : Files.Model.Undo_Entry;
      Found    : Boolean;
   begin
      if Progress.Recorded then
         Files.Model.Take_Undo (Model, Previous, Found);
         --  Taken: should the record below raise, a later one must not
         --  take the entry under it, which is not the batch's.
         Progress.Recorded := False;
      end if;
      --  Counted before the record, which may raise: a failed attempt is
      --  not retried until the next interval either.
      Progress.Attempted := True;
      Progress.Attempted_Count := Natural (Progress.From.Length);
      Progress.Last_Checkpoint := Ada.Real_Time.Clock;
      Progress.Recorded := Try_Record_Undo
        (Model, Progress.Kind, Progress.From, Progress.To,
         Forward     => Progress.Forward,
         Create_Kind => Progress.Create_Kind,
         Redoable    => Progress.Redoable,
         Provenance  =>
           (Identities           => Progress.Identities,
            Tree_Revisions       => Progress.Tree_Revisions,
            Retain_Verified_Main => Progress.Verified_Count,
            others               => <>));
      if Progress.Recorded
        and then Natural (Files.Model.Undo_From_Paths (Model).Length) = Natural (Progress.From.Length)
      then
         Progress.Verified_Count := Natural (Progress.From.Length);
      end if;
      if Progress.Durable then
         Files.History_Journal.Save (Model, Required => True);
      end if;
   end Record_Progress;

   procedure Checkpoint_Undo
     (Model    : in out Files.Model.Window_Model;
      Progress : in out Progressive_Undo) is
   begin
      if not Progress.Attempted
        or else Files.Timing.Elapsed (Ada.Real_Time.Clock, Progress.Last_Checkpoint, Checkpoint_Interval)
      then
         Record_Progress (Model, Progress);
      end if;
   end Checkpoint_Undo;

   function Finish_Undo
     (Model    : in out Files.Model.Window_Model;
      Progress : in out Progressive_Undo) return Undo_Outcome is
   begin
      if Natural (Progress.From.Length) /= Progress.Attempted_Count then
         Record_Progress (Model, Progress);
      end if;
      return (if Progress.From.Is_Empty or else Progress.Recorded then Undo_Covered else Undo_Unavailable);
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

end Files.Operations.Support;
