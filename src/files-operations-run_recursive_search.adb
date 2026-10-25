separate (Files.Operations)
function Run_Recursive_Search
  (Model    : in out Files.Model.Window_Model;
   Settings : Files.Settings.Settings_Model)
   return Operation_Result
is
   Query : constant String := Files.Model.Filter_Text (Model);
   Root  : constant String := Files.Model.Current_Path (Model);
begin
   if Query = "" then
      return Disabled (Model, "error.filter.empty");
   elsif Root = "" or else Files.Model.In_Recent_View (Model) then
      return Disabled (Model, "error.directory.load");
   elsif Files.Model.Background_Transfers (Model) then
      return Files.Operation_Jobs.Start (Model, Settings, Files.Operation_Jobs.Search_Names);
   end if;

   declare
      Search : constant Files.File_System.Recursive_Search_Result :=
        Files.File_System.Search_Recursive (Root, Query, Settings);
   begin
      if not Search.Success then
         Files.Model.Set_Error (Model, To_String (Search.Error_Key));
         return Make_Result
           (Operation_Failed, To_String (Search.Error_Key), Root);
      end if;

      Files.Model.Replace_Items (Model, Search.Items);
      Files.Model.Note_Search_Results (Model, Files.Types.Search_Names);
      Files.Model.Set_Directory_Signature
        (Model,
         Files.File_System.Directory_State (Root));
      Files.Model.Set_Error (Model, "");
      return Make_Result (Operation_Success, Path => Root);
   end;
end Run_Recursive_Search;
