separate (Check_All)
   procedure Check_Ada_Keyword_Identifiers is
   begin
      For_Each_Ada_Source (Root & "/src", Check_Ada_Keyword_Identifier_In_File'Access);
      For_Each_Ada_Source (Root & "/tests/tests/src", Check_Ada_Keyword_Identifier_In_File'Access);
      For_Each_Ada_Source (Root & "/tools/src", Check_Ada_Keyword_Identifier_In_File'Access);
   end Check_Ada_Keyword_Identifiers;
