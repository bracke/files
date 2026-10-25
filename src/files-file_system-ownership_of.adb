separate (Files.File_System)
procedure Ownership_Of
  (Path      : String;
   User_Id   : out Files.Types.Account_Id;
   Group_Id  : out Files.Types.Account_Id;
   Available : out Boolean) is
begin
   Hostkit.Metadata.File_Ownership (Path, User_Id, Group_Id, Available);
end Ownership_Of;
