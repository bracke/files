separate (Check_All)
   procedure Check_Line_Lengths is
   begin
      Check_Line_Lengths_In_Tree (Root & "/config");
      Check_Line_Lengths_In_Tree (Root & "/src");
      Check_Line_Lengths_In_Tree (Root & "/tests/tests/src");
      Check_Line_Lengths_In_Tree (Root & "/tools/config");
      Check_Line_Lengths_In_Tree (Root & "/tools/src");
      Check_Line_Lengths_In_Tree (Root & "/share");
      Check_Line_Lengths_In_File (Root & "/.gitignore");
      Check_Line_Lengths_In_File (Root & "/alire.toml");
      Check_Line_Lengths_In_File (Root & "/tests/alire.toml");
      Check_Line_Lengths_In_File (Root & "/files.gpr");
      Check_Line_Lengths_In_File (Root & "/tests/tests.gpr");
      Check_Line_Lengths_In_File (Root & "/tools/alire.toml");
      Check_Line_Lengths_In_File (Root & "/tools/files_check_all.gpr");
   end Check_Line_Lengths;
