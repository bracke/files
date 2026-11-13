separate (Files.Operations)
function Run_Search
  (Model    : in out Files.Model.Window_Model;
   Settings : Files.Settings.Settings_Model;
   Scope    : Files.Types.Tree_Search_Scope)
   return Operation_Result
is
   use type Files.Types.Search_Scope;
   Query : constant String := Files.Model.Filter_Text (Model);
   Root  : constant String := Files.Model.Current_Path (Model);
begin
   if Query = "" then
      return Disabled (Model, "error.filter.empty");
   elsif Root = "" or else Files.Model.In_Recent_View (Model) then
      return Disabled (Model, "error.directory.load");
   elsif Files.Model.Background_Transfers (Model) then
      return Files.Operation_Jobs.Start
        (Model, Settings,
         (if Scope = Files.Types.Search_Contents then Files.Operation_Jobs.Search_Contents
          else Files.Operation_Jobs.Search_Names));
   end if;

   declare
      Found : constant Files.File_System.Recursive_Search_Result :=
        (if Scope = Files.Types.Search_Contents then Files.File_System.Search_Contents (Root, Query, Settings)
         else Files.File_System.Search_Names (Root, Query, Settings));
   begin
      if not Found.Success then
         Files.Model.Set_Error (Model, To_String (Found.Error_Key));
         return Make_Result (Operation_Failed, To_String (Found.Error_Key), Root);
      end if;
      Files.Model.Replace_Items (Model, Found.Items);
      Files.Model.Note_Search_Results (Model, Scope);
      Files.Model.Set_Directory_Signature (Model, Files.File_System.Directory_State (Root));
      --  A partial answer is still shown, with a notice that it is one: a
      --  limit cut it short, or something under the root went unsearched.
      Files.Model.Set_Error
        (Model,
         (if Found.Truncated then "search.truncated"
          elsif Found.Incomplete then "search.incomplete"
          elsif Found.Items.Is_Empty then "search.no_matches"
          else ""));
      return Make_Result (Operation_Success, Path => Root);
   end;
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.Operations");
      Files.Model.Set_Error (Model, "error.search.failed");
      return Make_Result (Operation_Failed, "error.search.failed", Root);
end Run_Search;
