separate (Files.Operations.Editing.Commit_Rename)
function All_Failed return Operation_Result is
begin
   if Stranded_Path /= Null_Unbounded_String then
      First_Error_Key := To_Unbounded_String (Files.File_System.Rename_Stranded_Key);
      First_Error_Path := Stranded_Path;
      First_Error_Reason := Stranded;
   end if;
   declare
      Failed_Status : constant Operation_Status :=
        (if First_Error_Reason = Invalid_Name
         then Operation_Invalid_Name
         else Operation_Failed);
   begin
      Files.Model.Set_Error (Model, To_String (First_Error_Key), First_Error_Argument);
      if Need_Reload then
         Reload_With_Error (Model, Settings, To_String (First_Error_Key), First_Error_Argument);
      end if;
      return
        Make_Result
          (Failed_Status,
           To_String (First_Error_Key),
           To_String (First_Error_Path));
   end;
end All_Failed;
