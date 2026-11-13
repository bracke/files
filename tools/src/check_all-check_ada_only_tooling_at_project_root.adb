separate (Check_All)
   procedure Check_Ada_Only_Tooling_At_Project_Root is
      Search    : Ada.Directories.Search_Type;
      Dir_Entry : Ada.Directories.Directory_Entry_Type;
      Started   : Boolean := False;
   begin
      Ada.Directories.Start_Search
        (Search,
         Directory => Root,
         Pattern   => "*",
         Filter    =>
           [Ada.Directories.Ordinary_File => True,
           Ada.Directories.Directory     => False,
           Ada.Directories.Special_File  => False]);
      Started := True;

      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Dir_Entry);
            Full : constant String := Ada.Directories.Full_Name (Dir_Entry);
         begin
            Check_Ada_Only_Tooling_File (Name, Full);
            --  The Python scan covers the source trees, not the root itself.
            if Ends_With (Ada.Characters.Handling.To_Lower (Name), ".py") then
               Put_Line (Standard_Error, Full & ": non-Ada helper tooling is not allowed");
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
               raise Program_Error;
            end if;
         end;
      end loop;

      Ada.Directories.End_Search (Search);
      Started := False;
   exception
      when others =>
         if Started then
            Ada.Directories.End_Search (Search);
         end if;
         raise;
   end Check_Ada_Only_Tooling_At_Project_Root;
