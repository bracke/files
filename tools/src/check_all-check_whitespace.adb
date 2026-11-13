separate (Check_All)
   procedure Check_Whitespace is
   begin
      Check_Whitespace_In_Tree (Root & "/config");
      Check_Whitespace_In_Tree (Root & "/src");
      Check_Whitespace_In_Tree (Root & "/tests/tests/src");
      Check_Whitespace_In_Tree (Root & "/tools/config");
      Check_Whitespace_In_Tree (Root & "/tools/src");
      Check_Whitespace_In_Tree (Root & "/share");
      Check_Whitespace_In_File (Root & "/.gitignore");
      Check_Whitespace_In_File (Root & "/alire.toml");
      Check_Whitespace_In_File (Root & "/tests/.gitignore");
      Check_Whitespace_In_File (Root & "/tests/alire.toml");
      Check_Whitespace_In_File (Root & "/files.gpr");
      Check_Whitespace_In_File (Root & "/tests/tests.gpr");
      Check_Whitespace_In_File (Root & "/tools/alire.toml");
      Check_Whitespace_In_File (Root & "/tools/files_check_all.gpr");
   end Check_Whitespace;
