with Files.Model.Jobs;
with Files.Paste_States;
separate (Files.Operations.Paste)
--  Finalize an armed paste execution: record one undo covering what it did
--  (Record_Paste_Execution), reload, and clear the execution state. A
--  non-empty Error_Key reports a mid-run write failure; Kept names a failed
--  move's copy left beside its still present source.
function Finalize_Paste_Execution
  (Model     : in out Files.Model.Window_Model;
   Settings  : Files.Settings.Settings_Model;
   Error_Key : String;
   Kept      : Kept_Copy := No_Kept_Copy)
   return Operation_Result
is
   --  Read once: everything recorded below is what the paste gathered.
   Exec       : constant Files.Paste_States.Execution_State := Files.Model.Pasting.Execution_Of (Model);
   --  Destinations a Replace overwrote.
   Replaced   : Files.Undo.History.Recorded_Original_Vectors.Vector renames Exec.Replaced;
   Has_Kept   : constant Boolean := Length (Kept.Dest_Path) > 0;
   First_Dest : constant String := To_String (Exec.First_Dest);
   --  A kept copy no longer verifiable on a path an original goes back to
   --  makes the whole undo unsafe: Try_Record_Undo records nothing, and the
   --  paste reports it rather than letting the missing Undo pass unnoticed.
   Unsafe_Kept : constant Boolean :=
     Has_Kept
     and then (for some Given of Replaced => Given.Original.Target = Kept.Dest_Path)
     and then not Files.File_System.Creation_Matches
       (To_String (Kept.Dest_Path), To_String (Kept.Identity), To_String (Kept.Tree_Revision), False);
   --  The move's own failure stays the error; the missing Undo is reported
   --  as the error only when nothing else failed (a cancelled paste), and
   --  otherwise joins it as a second message.
   Undo_Unavailable_Key : constant String := "error.paste.undo_unavailable";
   Reported_Key : constant String :=
     (if Unsafe_Kept and then Error_Key = "" then Undo_Unavailable_Key else Error_Key);
   Notice_Key : constant String :=
     (if Unsafe_Kept and then Error_Key /= "" then Undo_Unavailable_Key else "");

   --  Record Reported_Key as the window's error, with Notice_Key beside it.
   procedure Report is
   begin
      Files.Model.Set_Error (Model, Reported_Key);
      if Notice_Key /= "" then
         Files.Model.Set_Error_Notice (Model, Notice_Key);
      end if;
   end Report;
begin
   Record_Paste_Execution (Model, Kept);
   Files.Model.Jobs.End_Foreground_Job (Model);

   if Files.Model.Jobs.Background_Transfers (Model) then
      --  Preserve mutation errors while a nonmodal helper refreshes the view.
      Report;
      declare
         Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
      begin
         if Reported_Key /= "" then
            return Make_Result (Operation_Failed, Reported_Key, Files.Model.Current_Path (Model));
         elsif Reload.Status /= Operation_Success then
            return Reload;
         end if;
      end;
      return Make_Result (Operation_Success, Path => First_Dest);
   end if;

   declare
      Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
   begin
      if Reload.Status /= Operation_Success then
         if Reported_Key /= "" then
            Report;
            return Make_Result (Operation_Failed, Reported_Key, Files.Model.Current_Path (Model));
         end if;
         return Reload;
      end if;
   end;

   if Reported_Key /= "" then
      Report;
      return Make_Result (Operation_Failed, Reported_Key, Files.Model.Current_Path (Model));
   end if;

   Files.Model.Set_Error (Model, "");
   return Make_Result (Operation_Success, Path => First_Dest);
end Finalize_Paste_Execution;
