separate (Files.File_System)
procedure Ownership_Of
  (Path      : String;
   User_Id   : out Natural;
   Group_Id  : out Natural;
   Available : out Boolean) is
begin
   Hostkit.Metadata.File_Ownership (Path, User_Id, Group_Id, Available);
end Ownership_Of;
