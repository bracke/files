separate (Files.Model)
procedure Commit_Path_Input
  (Model  : in out Window_Model;
   Result : Files.File_System.Path_Result;
   Items  : Files.Items.Item_Vectors.Vector) is
begin
   Touch (Model);
   if Result.Status = Files.File_System.Path_Valid then
      Navigate_To (Model, To_String (Result.Directory_Path), Items);
      Model.Focus_Value := Files.Types.Focus_None;
   else
      Model.Path_Input.Valid := False;
      Model.Path_Input.Error := Result.Error_Key;
   end if;
end Commit_Path_Input;
