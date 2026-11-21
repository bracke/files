with Files.Text_Basics;
with Files.Text_Case;

separate (Files.File_System.Thumbnails)
function Is_Image_Item
  (Kind     : Files.Types.Item_Kind;
   Filetype : String;
   Name     : String;
   Icon_Id  : String)
   return Boolean
is
   Extension : constant String := Files.File_Types.Normalized_Extension_Of (Name);
begin
   if Kind = Files.Types.Directory_Item
     or else Kind = Files.Types.Symlink_Item
   then
      return False;
   end if;

   return Files.Text_Basics.Starts_With (Files.Text_Case.To_Lower_Ascii (Filetype), "image/")
     or else Files.Text_Case.To_Lower_Ascii (Icon_Id) = "image"
     or else Extension = "png"
     or else Extension = "jpg"
     or else Extension = "jpeg"
     or else Extension = "gif"
     or else Extension = "bmp"
     or else Extension = "webp"
     or else Extension = "tif"
     or else Extension = "tiff"
     or else Extension = "ppm";
end Is_Image_Item;
