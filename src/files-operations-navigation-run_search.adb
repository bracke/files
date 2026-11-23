with Files.Model.Filtering;
separate (Files.Operations.Navigation)
function Run_Search
  (Model    : in out Files.Model.Window_Model;
   Settings : Files.Settings.Settings_Model;
   Scope    : Files.UI_Types.Tree_Search_Scope)
   return Operation_Result
is
   Root : constant String := Files.Model.Current_Path (Model);
begin
   declare
      Refusal : constant Operation_Result := Search_Refusal (Model);
   begin
      if Refusal.Status /= Operation_Success then
         return Refusal;
      end if;
   end;
   return Search_Current_Folder (Model, Settings, Scope, Files.Model.Filtering.Filter_Text (Model));
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.Operations");
      Files.Model.Set_Error (Model, "error.search.failed");
      return Make_Result (Operation_Failed, "error.search.failed", Root);
end Run_Search;
