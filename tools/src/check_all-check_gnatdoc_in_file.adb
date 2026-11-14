separate (Check_All)
   procedure Check_GNATdoc_In_File (Path : String) is
      procedure Guard is
      begin
         Project_Tools.Ada_Source.Require_Public_GNATdoc_Tags (Path);
      end Guard;
   begin
      Guarded (Guard'Access);
   end Check_GNATdoc_In_File;
