separate (Files.Operations)
function Refresh_If_Changed
  (Model    : in out Files.Model.Window_Model;
   Settings : Files.Settings.Settings_Model)
   return Operation_Result
is
begin
   if Files.Model.Background_Transfers (Model) then
      return Files.Refresh_Jobs.Start (Model, Settings);
   end if;
   declare
      Change : constant Files.File_System.Directory_Change_Result :=
        Files.File_System.Detect_Directory_Change
          (Files.Model.Directory_Signature_Of (Model), Files.Model.Current_Path (Model));
   begin
      if Length (Change.Error_Key) > 0 then
         Files.Model.Set_Error (Model, To_String (Change.Error_Key));
         return Make_Result (Operation_Failed, To_String (Change.Error_Key), Files.Model.Current_Path (Model));
      elsif not Change.Changed then
         Files.Model.Set_Directory_Signature (Model, Change.After_State);
         Files.Model.Set_Error (Model, "");
         return Make_Result (Operation_Success, Path => Files.Model.Current_Path (Model));
      end if;

      --  Preserve the complete selection across an auto-refresh triggered by
      --  a directory change, when those items still exist.
      return Reload_Current_Directory
        (Model, Settings, Preserve_Selection => True);
   end;
end Refresh_If_Changed;
