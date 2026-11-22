separate (Files.Model)
procedure Set_Error
  (Model     : in out Window_Model;
   Error_Key : String;
   Path      : String := "") is
begin
   --  Clearing an error that is already clear (Ctrl+F, Copy Path and many
   --  more do) changes nothing a refresh request snapshotted, so it must
   --  not cancel the folder read in flight by moving the listing revision.
   if Model.Last_Error = Error_Key
     and then Model.Last_Error_Path_Value = Path
     and then Length (Model.Last_Error_Notice_Key) = 0
   then
      return;
   end if;
   Touch_Header (Model);
   --  Refresh requests also snapshot the current error so a completed load
   --  cannot clear or restore an error recorded after the request began.
   Model.Listing_Revision_Value := Model.Listing_Revision_Value + 1;
   Model.Last_Error := To_Unbounded_String (Error_Key);
   Model.Last_Error_Path_Value := To_Unbounded_String (Path);
   Model.Last_Error_Notice_Key := Null_Unbounded_String;
end Set_Error;
