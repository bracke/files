package body Files.File_System.Thumbnails.Testing is

   function Png_Fast_Path (Source_Path : String; Size : Positive; Target_Path : String) return Boolean is
     (Try_Write_Decoded_Png_Thumbnail (Source_Path, Size, Target_Path));

   procedure List_Cache
     (Cache_Directory : String;
      Max_Entries     : Positive;
      Listed          : out Boolean;
      Count           : out Natural)
   is
      Index : constant Cache_Index := List_Thumbnail_Cache (Cache_Directory, Max_Entries);
   begin
      Listed := Index.Listed;
      Count := Natural (Index.Names.Length);
   end List_Cache;

end Files.File_System.Thumbnails.Testing;
