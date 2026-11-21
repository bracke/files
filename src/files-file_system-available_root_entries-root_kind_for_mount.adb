separate (Files.File_System.Available_Root_Entries)
function Root_Kind_For_Mount
  (Mount_Point     : String;
   Filesystem_Type : String)
   return Root_Kind is
begin
   if Hostkit.Mounts.Is_Network (Filesystem_Type, Mount_Point)
     or else (Desktop_Mounts /= "" and then Starts_With (Mount_Point, Mounts_Prefix))
   then
      return Root_Network_Mount;
   end if;

   return Root_Mount;
end Root_Kind_For_Mount;
