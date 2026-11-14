separate (Files.Model)
procedure Set_Error
  (Model     : in out Window_Model;
   Error_Key : String;
   Path      : String := "") is
begin
   Touch (Model);
   --  Refresh requests also snapshot the current error so a completed load
   --  cannot clear or restore an error recorded after the request began.
   Model.Listing_Revision_Value := Model.Listing_Revision_Value + 1;
   Model.Last_Error := To_Unbounded_String (Error_Key);
   Model.Last_Error_Path_Value := To_Unbounded_String (Path);
   Model.Last_Error_Notice_Key := Null_Unbounded_String;
end Set_Error;
