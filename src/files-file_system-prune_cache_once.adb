separate (Files.File_System)
--  Once per run, at the default budget. See the note above for why not per
--  write.
procedure Prune_Cache_Once (Cache_Directory : String) is
   Prune : Boolean;
begin
   Cache_Prune_Registry.Claim (Cache_Directory, Prune);
   if not Prune then
      return;
   end if;
   Prune_Thumbnail_Cache (Cache_Directory, Cache_Byte_Budget);
end Prune_Cache_Once;
