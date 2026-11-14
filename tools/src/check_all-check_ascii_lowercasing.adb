separate (Check_All)
   procedure Check_Ascii_Lowercasing is
      procedure Guard is
      begin
         Project_Tools.Ada_Source.Require_No_Code_Tokens_In_Tree
           (Root & "/src", [To_Unbounded_String ("Ada.Characters.Handling.To_Lower")]);
      end Guard;
   begin
      Guarded (Guard'Access);
   end Check_Ascii_Lowercasing;
