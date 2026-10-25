separate (Files_Suite.Operations)
   procedure Remove_Transport_Fixture (Path : Files.Types.UString) is
   begin
      if Length (Path) > 0 and then Ada.Directories.Exists (To_String (Path)) then
         Project_Tools.Files.Delete_Tree (To_String (Path));
      end if;
   end Remove_Transport_Fixture;
