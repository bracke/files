separate (Check_All)
   procedure Check_Ada_Keyword_Identifiers is
   begin
      Check_Ada_Keyword_Identifiers_In_Tree (Root & "/src");
      Check_Ada_Keyword_Identifiers_In_Tree (Root & "/tests/tests/src");
      Check_Ada_Keyword_Identifiers_In_Tree (Root & "/tools/src");
   end Check_Ada_Keyword_Identifiers;
