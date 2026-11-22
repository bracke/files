with Hostkit.Metadata_Copy;
separate (Files.File_System.Copying.Copy_Node)
procedure Copy_Metadata is
   --  Null but in the test suite (Files.File_System.Testing).
   Hook : constant Copy_Hook := After_Metadata;
begin
   if not Hostkit.Metadata_Copy.Apply
     (Metadata, Destination_Path, Preserve_Ownership)
   then
      raise Ada.Directories.Use_Error;
   end if;
   Metadata := Hostkit.Metadata_Copy.No_Snapshot;
   if Hook /= null then
      Hook (Destination_Path);
   end if;
end Copy_Metadata;
