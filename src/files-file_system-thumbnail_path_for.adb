separate (Files.File_System)
   function Thumbnail_Path_For
     (Source_Path      : String;
      Cache_Directory : String;
      Size            : Positive := 64)
      return String is
   begin
      return
        Join_Path
          (Cache_Directory,
           "thumb_"
           & Sanitized_Thumbnail_Extension (Source_Path)
           & "_"
           & Image_No_Space (Size)
           & "_"
           & Image_No_Space (Thumbnail_Path_Checksum (Source_Path))
           & ".ppm");
   end Thumbnail_Path_For;
