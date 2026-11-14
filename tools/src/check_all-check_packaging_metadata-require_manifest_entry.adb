separate (Check_All.Check_Packaging_Metadata)
   procedure Require_Manifest_Entry
     (Path    : String;
      Message : String) is
      Manifest : constant String := Root & "/share/files/package.manifest";
      Content  : constant String := To_String (Project_Tools.Text.Read_Text_File (Manifest));
      Found    : Boolean := False;

      procedure Check_Line (Raw : String; Number : Positive) is
         pragma Unreferenced (Number);
      begin
         if Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both) = Path then
            Found := True;
         end if;
      end Check_Line;
   begin
      For_Each_Line (Content, Check_Line'Access);

      if not Found then
         Put_Line (Standard_Error, Message);
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      end if;
   end Require_Manifest_Entry;
