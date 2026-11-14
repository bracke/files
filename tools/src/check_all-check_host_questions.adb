separate (Check_All)
   procedure Check_Host_Questions is
   begin
      for Item of Project_Tools.Files.List_Tree (Root & "/src", "*.ad?", Generated_Directories) loop
         declare
            Path : constant String := To_String (Item);
            Code : constant String := Code_Of (To_String (Project_Tools.Text.Read_Text_File (Path)));
         begin
            if Ada.Strings.Fixed.Index (Code, "Alire_Host_OS") > 0 then
               Report (Path & ": asks the build's OS string; use Hostkit.Host.Current");
            end if;
         end;
      end loop;
   end Check_Host_Questions;
