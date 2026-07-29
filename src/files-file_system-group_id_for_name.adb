separate (Files.File_System)
   function Group_Id_For_Name
     (Name  : String;
      Found : out Boolean)
      return Natural is
   begin
      return Files.Platform.Metadata.Group_Id_For_Name (Name, Found);
   end Group_Id_For_Name;
