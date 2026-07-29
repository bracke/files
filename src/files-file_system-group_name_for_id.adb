separate (Files.File_System)
   function Group_Name_For_Id (Id : Natural) return String is
      Position : constant Id_Name_Maps.Cursor := Group_Name_Cache.Find (Id);
   begin
      if Id_Name_Maps.Has_Element (Position) then
         return To_String (Id_Name_Maps.Element (Position));
      end if;
      declare
         Name : constant String := Files.Platform.Metadata.Group_Name_For_Id (Id);
      begin
         Group_Name_Cache.Insert (Id, To_Unbounded_String (Name));
         return Name;
      end;
   end Group_Name_For_Id;
