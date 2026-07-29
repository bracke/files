separate (Files.File_System)
   function User_Id_For_Name
     (Name  : String;
      Found : out Boolean)
      return Natural is
   begin
      return Files.Platform.Metadata.User_Id_For_Name (Name, Found);
   end User_Id_For_Name;
