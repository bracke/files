--  Test-only views of Files.File_System.Thumbnails.
package Files.File_System.Thumbnails.Testing is

   --  The pure-Ada PNG thumbnail path alone, without the gdk-pixbuf fallback.
   --
   --  @param Source_Path PNG to decode.
   --  @param Size Thumbnail side.
   --  @param Target_Path Where to write the thumbnail.
   --  @return True when that path decoded and wrote it.
   function Png_Fast_Path (Source_Path : String; Size : Positive; Target_Path : String) return Boolean;

   --  A cache listing under a cap of Max_Entries thumbnails.
   --
   --  @param Cache_Directory The cache directory.
   --  @param Max_Entries The listing's cap.
   --  @param Listed Whether the listing stayed under the cap.
   --  @param Count How many thumbnail names it holds.
   procedure List_Cache
     (Cache_Directory : String;
      Max_Entries     : Positive;
      Listed          : out Boolean;
      Count           : out Natural);

end Files.File_System.Thumbnails.Testing;
