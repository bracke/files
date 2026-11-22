separate (Files.Job_Drivers.Operation.Advance)
function Act_On (Choice : Disposition) return Files.Operation_Results.Operation_Result is
begin
   case Choice is
      when Discard =>
         return (Status => Files.Operation_Results.Operation_Success, others => <>);
      when Reload_View =>
         --  Finalize error/history before the refresh captures this
         --  revision. A result from an older view must not refresh or
         --  alter the diagnostic of the view now displayed, but an
         --  edit within the same view must not cost it the reload.
         Conclude_In_Origin (To_String (Done.Visible_Error), Kind_Known => True);
         return Reported;
      when Leave_View =>
         --  The filesystem work and restored history remain valid, but
         --  its directory snapshot and diagnostic belong to the view it
         --  started from, not the one now displayed. A history given
         --  up is still said, as it concerns the window's Undo.
         Note_History_Lost (Done.Kind);
         return Reported;
      when Apply_Snapshot =>
         Apply_Snapshot;
         return Report_In_View;
      when Owe_Reload =>
         --  Its snapshot predates a later listing change: reread it
         --  rather than leave the operation's new entries unlisted,
         --  once the diagnostic it must preserve is final.
         Files.Model.Set_Error (Model, To_String (Done.Visible_Error));
         Note_History_Lost (Done.Kind);
         Reload_Current_View (To_String (Done.Selection));
         Files.Refresh.Ensure_Selected_Item_Extra (Model, Settings.Show_Hidden_Files);
         return Done.Result;
      when Report =>
         return Report_In_View;
   end case;
end Act_On;
