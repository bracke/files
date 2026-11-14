separate (Files.File_System)
function Account_Name_For_Id
  (Kind : Name_Account;
   Id   : Files.Types.Account_Id)
   return String
is
   Cache    : Id_Name_Maps.Map renames Account_Name_Caches (Kind);
   Position : constant Id_Name_Maps.Cursor := Cache.Find (Id);
begin
   if Id_Name_Maps.Has_Element (Position) then
      return To_String (Id_Name_Maps.Element (Position));
   end if;
   declare
      Name : constant String :=
        (case Kind is
            when User_Names  => Hostkit.Metadata.User_Name_For_Id (Id),
            when Group_Names => Hostkit.Metadata.Group_Name_For_Id (Id));
   begin
      Cache.Insert (Id, To_Unbounded_String (Name));
      return Name;
   end;
end Account_Name_For_Id;
