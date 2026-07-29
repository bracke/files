separate (Files.File_System)
   function Should_Auto_Generate_Thumbnail
     (Kind     : Files.Types.Item_Kind;
      Filetype : String;
      Name     : String;
      Icon_Id  : String)
      return Boolean is
   begin
      return Is_Image_Item (Kind, Filetype, Name, Icon_Id);
   end Should_Auto_Generate_Thumbnail;
