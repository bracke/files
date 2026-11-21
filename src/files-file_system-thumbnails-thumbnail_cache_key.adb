separate (Files.File_System.Thumbnails)
function Thumbnail_Cache_Key
  (Source_Path : String)
   return String
is
begin
   return Files.Digests.SHA256_Hex
     (Source_Path & ASCII.NUL
      & Files.File_Identities.Token (Source_Path) & ASCII.NUL
      & Files.File_Identities.Revision (Source_Path));
end Thumbnail_Cache_Key;
