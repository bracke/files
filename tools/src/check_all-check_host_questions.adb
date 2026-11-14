separate (Check_All)
   procedure Check_Host_Questions is
   begin
      for Item of Project_Tools.Files.List_Tree (Root & "/src", "*.ad?", Generated_Directories) loop
         declare
            Path : constant String := To_String (Item);
            Code : constant String := Code_Of (To_String (Project_Tools.Text.Read_Text_File (Path)));
         begin
            if Ada.Strings.Fixed.Index (Code, "Alire_Host_OS") > 0 then
               Put_Line (Standard_Error, Path & ": asks the build's OS string; use Hostkit.Host.Current");
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
               raise Program_Error;
            end if;
         end;
      end loop;
   end Check_Host_Questions;
