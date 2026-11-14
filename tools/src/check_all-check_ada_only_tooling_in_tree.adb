separate (Check_All)
   procedure Check_Ada_Only_Tooling_In_Tree (Path : String) is
   begin
      for Item of Project_Tools.Files.List_Tree (Path, "*", Generated_Directories) loop
         declare
            Full : constant String := To_String (Item);
         begin
            Check_Ada_Only_Tooling_File (Ada.Directories.Simple_Name (Full), Full);
         end;
      end loop;
   end Check_Ada_Only_Tooling_In_Tree;
