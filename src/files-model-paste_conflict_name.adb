separate (Files.Model)
function Paste_Conflict_Name
  (Model : Window_Model)
   return String is
begin
   if Model.Paste_Conflict.Active
     and then Model.Paste_Conflict.Index
              in Model.Paste_Conflict.Items.First_Index
                 .. Model.Paste_Conflict.Items.Last_Index
   then
      return To_String
        (Model.Paste_Conflict.Items.Element
           (Model.Paste_Conflict.Index).Dest_Name);
   end if;
   return "";
end Paste_Conflict_Name;
