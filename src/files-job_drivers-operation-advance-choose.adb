with Files.Model.Filtering;
separate (Files.Job_Drivers.Operation.Advance)
function Choose return Disposition is
   use type Files.UI_Types.Search_Scope;
   Succeeded : constant Boolean :=
     not Cancelled and then Done.Result.Status = Files.Operation_Results.Operation_Success;
begin
   if Done.Kind in Search_Names | Search_Contents
     and then (not Matches_Current_Context (Work) or else Work.Query /= Files.Model.Filtering.Filter_Text (Model))
   then
      return Discard;
   elsif Done.Kind in Trash | Delete_Permanently | Restore
     and then Succeeded and then not History_Lost
     and then Done.Searched /= Files.UI_Types.Filter_Here
     --  The helper's model searched again after acting (a search sets the
     --  signature it read; a helper's model starts with none).
     and then Done.Signature.Taken
     and then Matches_Current_Context (Work)
     and then Files.Model.Filtering.Search_Results_Are_Active (Model)
     and then Files.Model.Filtering.Search_Scope_Of (Model) = Done.Searched
     and then Files.Model.Filtering.Filter_Text (Model) = To_String (Work.Query)
   then
      --  Its results are the view after the operation: shown as they are,
      --  not searched for a second time.
      return Apply_Snapshot;
   elsif Done.Kind in Trash | Delete_Permanently | Restore | Empty_Trash | Undo | Redo
     or else (Done.Kind in Duplicate | Compress_Zip | Compress_Seven_Zip | Extract and then not Succeeded)
   then
      return Reload_View;
   elsif Succeeded and then Matches_Current_Context (Work) then
      return Apply_Snapshot;
   elsif not Same_View then
      return Leave_View;
   elsif Succeeded and then Done.Kind not in Search_Names | Search_Contents then
      return Owe_Reload;
   else
      return Report;
   end if;
end Choose;
