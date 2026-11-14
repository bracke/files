separate (Check_All)
   procedure Check_Ada_Only_Tooling_File
     (Name : String;
      Full : String) is
   begin
      if Has_Non_Ada_Tooling_Extension (Name) then
         Report (Full & ": non-Ada helper tooling is not allowed");
      elsif Has_Parser_Generator_Extension (Name) then
         Report (Full & ": external parser generator input is not allowed");
      elsif Has_Shebang (Full) then
         Report (Full & ": shebang helper tooling is not allowed");
      end if;
   end Check_Ada_Only_Tooling_File;
