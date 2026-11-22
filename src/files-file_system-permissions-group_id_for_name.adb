separate (Files.File_System.Permissions)
function Group_Id_For_Name
  (Name  : String;
   Found : out Boolean)
   return Files.Types.Account_Id is
begin
   return Hostkit.Metadata.Group_Id_For_Name (Name, Found);
end Group_Id_For_Name;
