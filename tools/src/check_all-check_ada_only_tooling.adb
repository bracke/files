separate (Check_All)
   procedure Check_Ada_Only_Tooling is
      Python_Errors : Natural := 0;

      procedure Scan_Python (Path : String) is
      begin
         if Project_Tools.Files.Directory_Exists (Path) then
            Project_Tools.Tree_Checks.Check_No_Generated_Python (Python_Errors, Path);
         end if;
      end Scan_Python;
   begin
      Check_Ada_Only_Tooling_At_Project_Root;
      Check_Ada_Only_Tooling_In_Tree (Root & "/config");
      Check_Ada_Only_Tooling_In_Tree (Root & "/scripts");
      Check_Ada_Only_Tooling_In_Tree (Root & "/src");
      Check_Ada_Only_Tooling_In_Tree (Root & "/tests");
      Check_Ada_Only_Tooling_In_Tree (Root & "/tools");
      Check_Ada_Only_Tooling_In_Tree (Root & "/share");
      Check_Ada_Only_Tooling_In_Tree (Root & "/.github");
      Check_Ada_Only_Tooling_In_Tree (Root & "/.claude");
      Check_Ada_Only_Tooling_In_Tree (Root & "/.config");

      --  Delegate Python-artifact detection to the shared tree check across the
      --  same source trees the inline scan covers.
      Scan_Python (Root & "/config");
      Scan_Python (Root & "/scripts");
      Scan_Python (Root & "/src");
      Scan_Python (Root & "/tests");
      Scan_Python (Root & "/tools");
      Scan_Python (Root & "/share");
      Scan_Python (Root & "/.github");
      Scan_Python (Root & "/.claude");
      Scan_Python (Root & "/.config");

      if Python_Errors > 0 then
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      end if;
   end Check_Ada_Only_Tooling;
