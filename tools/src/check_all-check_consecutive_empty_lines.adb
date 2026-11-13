separate (Check_All)
   procedure Check_Consecutive_Empty_Lines is
   begin
      Check_Consecutive_Empty_Lines_In_Tree (Root & "/config");
      Check_Consecutive_Empty_Lines_In_Tree (Root & "/src");
      Check_Consecutive_Empty_Lines_In_Tree (Root & "/tests/tests/src");
      Check_Consecutive_Empty_Lines_In_Tree (Root & "/tools/config");
      Check_Consecutive_Empty_Lines_In_Tree (Root & "/tools/src");
      Check_Consecutive_Empty_Lines_In_Tree (Root & "/share");
      Check_Consecutive_Empty_Lines_In_File (Root & "/.gitignore");
      Check_Consecutive_Empty_Lines_In_File (Root & "/alire.toml");
      Check_Consecutive_Empty_Lines_In_File (Root & "/tests/alire.toml");
      Check_Consecutive_Empty_Lines_In_File (Root & "/files.gpr");
      Check_Consecutive_Empty_Lines_In_File (Root & "/tests/tests.gpr");
      Check_Consecutive_Empty_Lines_In_File (Root & "/tools/alire.toml");
      Check_Consecutive_Empty_Lines_In_File (Root & "/tools/files_check_all.gpr");
   end Check_Consecutive_Empty_Lines;
