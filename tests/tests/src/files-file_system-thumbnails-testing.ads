--  Test-only views of Files.File_System.Thumbnails.
package Files.File_System.Thumbnails.Testing is

   --  The pure-Ada PNG thumbnail path alone, without the gdk-pixbuf fallback.
   --
   --  @param Source_Path PNG to decode.
   --  @param Size Thumbnail side.
   --  @param Target_Path Where to write the thumbnail.
   --  @return True when that path decoded and wrote it.
   function Png_Fast_Path (Source_Path : String; Size : Positive; Target_Path : String) return Boolean;

end Files.File_System.Thumbnails.Testing;
