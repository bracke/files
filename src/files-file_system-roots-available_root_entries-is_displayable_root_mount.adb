separate (Files.File_System.Roots.Available_Root_Entries)
function Is_Displayable_Root_Mount
  (Mount_Point     : String;
   Filesystem_Type : String)
   return Boolean is
begin
   return Is_User_Visible_Mount_Point (Mount_Point)
     and then not Is_Pseudo_Mount_Type (Filesystem_Type);
end Is_Displayable_Root_Mount;
