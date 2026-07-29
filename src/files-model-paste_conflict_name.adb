separate (Files.Model)
   function Paste_Conflict_Name
     (Model : Window_Model)
      return String is
   begin
      if Model.Paste_Conflict_Active_Value
        and then Model.Paste_Conflict_Index_Value
                 in Model.Paste_Conflict_Items_Value.First_Index
                    .. Model.Paste_Conflict_Items_Value.Last_Index
      then
         return To_String
           (Model.Paste_Conflict_Items_Value.Element
              (Model.Paste_Conflict_Index_Value).Dest_Name);
      end if;
      return "";
   end Paste_Conflict_Name;
