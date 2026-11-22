separate (Files.File_System.Roots.Available_Root_Entries)
procedure Append_Mounts is
begin
   for Mount of Mounts loop
      declare
         Mount_Point     : constant String := To_String (Mount.Mount_Point);
         Filesystem_Type : constant String := To_String (Mount.Filesystem_Type);
      begin
         if Is_Displayable_Root_Mount (Mount_Point, Filesystem_Type) then
            Append_If_Directory (Mount_Point, Root_Kind_For_Mount (Mount_Point, Filesystem_Type));
         end if;
      end;
   end loop;
end Append_Mounts;
