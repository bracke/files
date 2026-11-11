separate (Files.File_System.Thumbnails)
function Thumbnail_Path_For
  (Source_Path      : String;
   Cache_Directory : String;
   Size            : Positive := 64)
   return String is
begin
   return
     Hostkit.Fs.Join
       (Cache_Directory,
        "thumb_"
        & Sanitized_Thumbnail_Extension (Source_Path)
        & "_"
        & Natural_Text (Size)
        & "_"
        & Thumbnail_Cache_Key (Source_Path)
        & ".ppm");
end Thumbnail_Path_For;
