separate (Check_All)
   procedure Check_GNATdoc_Comments is
   begin
      for Tree of String_List'
        [To_Unbounded_String (Root & "/src"),
         To_Unbounded_String (Root & "/tests/tests/src"),
         To_Unbounded_String (Root & "/tools/src")]
      loop
         for Spec of Project_Tools.Files.List_Tree (To_String (Tree), "*.ads", Generated_Directories) loop
            Check_GNATdoc_In_File (To_String (Spec));
         end loop;
      end loop;
   end Check_GNATdoc_Comments;
