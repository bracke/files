package body Files.File_System.Thumbnails.Testing is

   function Png_Fast_Path (Source_Path : String; Size : Positive; Target_Path : String) return Boolean is
     (Try_Write_Decoded_Png_Thumbnail (Source_Path, Size, Target_Path));

end Files.File_System.Thumbnails.Testing;
