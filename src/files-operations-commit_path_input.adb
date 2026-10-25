separate (Files.Operations)
function Commit_Path_Input
  (Model    : in out Files.Model.Window_Model;
   Settings : Files.Settings.Settings_Model)
   return Operation_Result
is
   Path_Result : constant Files.File_System.Path_Result :=
     Files.File_System.Normalize_Path
       (Files.File_System.Expand_User_Path (Files.Model.Path_Input_Text (Model)));
   Empty_Items : Files.File_System.Item_Vectors.Vector;
begin
   if Path_Result.Status /= Files.File_System.Path_Valid then
      Files.Model.Commit_Path_Input (Model, Path_Result, Empty_Items);
      Files.Model.Set_Error (Model, To_String (Path_Result.Error_Key));
      return Make_Result (Operation_Failed, To_String (Path_Result.Error_Key));
   end if;

   declare
      Load : constant Files.File_System.Directory_Load_Result :=
        Files.File_System.Load_Directory_Deferring_Thumbnails (To_String (Path_Result.Directory_Path), Settings);
   begin
      if not Load.Success then
         Files.Model.Set_Error (Model, To_String (Load.Error_Key));
         return Make_Result (Operation_Failed, To_String (Load.Error_Key), To_String (Path_Result.Directory_Path));
      end if;

      Files.Model.Commit_Path_Input (Model, Path_Result, Load.Items);
      Settle_Current_Is_Trash (Model);
      Files.Model.Set_Directory_Signature
        (Model,
         Files.File_System.Directory_State (To_String (Path_Result.Directory_Path)));
      Files.Model.Set_Error (Model, "");
      --  Last, once the listing it refreshes is the current one.
      Support.Generate_Missing_Thumbnails (Model, Settings, Load.Items);
      return Make_Result (Operation_Navigated, Path => To_String (Path_Result.Directory_Path));
   end;
end Commit_Path_Input;
