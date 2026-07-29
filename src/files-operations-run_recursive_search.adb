separate (Files.Operations)
   function Run_Recursive_Search
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Query : constant String := Files.Model.Filter_Text (Model);
   begin
      if Query = "" then
         return Disabled (Model, "error.filter.empty");
      end if;

      declare
         Search : constant Files.File_System.Recursive_Search_Result :=
           Files.File_System.Search_Recursive (Files.Model.Current_Path (Model), Query, Settings);
      begin
         if not Search.Success then
            Files.Model.Set_Error (Model, To_String (Search.Error_Key));
            return Make_Result
              (Operation_Failed, To_String (Search.Error_Key), Files.Model.Current_Path (Model));
         end if;

         Files.Model.Replace_Items (Model, Search.Items);
         Files.Model.Note_Search_Results (Model, Files.Types.Search_Names);
         Files.Model.Set_Directory_Signature
           (Model,
            Files.File_System.Directory_State (Files.Model.Current_Path (Model)));
         Files.Model.Set_Error (Model, "");
         return Make_Result (Operation_Success, Path => Files.Model.Current_Path (Model));
      end;
   end Run_Recursive_Search;
