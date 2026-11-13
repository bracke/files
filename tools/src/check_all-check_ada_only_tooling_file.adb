separate (Check_All)
   procedure Check_Ada_Only_Tooling_File
     (Name : String;
      Full : String) is
   begin
      if Has_Non_Ada_Tooling_Extension (Name) then
         Put_Line (Standard_Error, Full & ": non-Ada helper tooling is not allowed");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      elsif Has_Parser_Generator_Extension (Name) then
         Put_Line (Standard_Error, Full & ": external parser generator input is not allowed");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      elsif Has_Shebang (Full) then
         Put_Line (Standard_Error, Full & ": shebang helper tooling is not allowed");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      end if;
   end Check_Ada_Only_Tooling_File;
