separate (Check_All)
   procedure Check_GNATdoc_Comments is
   begin
      Check_GNATdoc_In_Tree (Root & "/src");
      Check_GNATdoc_In_Tree (Root & "/tests/tests/src");
      Check_GNATdoc_In_Tree (Root & "/tools/src");
   end Check_GNATdoc_Comments;
