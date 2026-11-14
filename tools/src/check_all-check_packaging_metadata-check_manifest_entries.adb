separate (Check_All.Check_Packaging_Metadata)
   procedure Check_Manifest_Entries is
      package Manifest_Path_Sets is new Ada.Containers.Indefinite_Hashed_Sets
        (Element_Type        => String,
         Hash                => Ada.Strings.Hash,
         Equivalent_Elements => "=");

      Manifest : constant String := Root & "/share/files/package.manifest";
      Content  : constant String := To_String (Project_Tools.Text.Read_Text_File (Manifest));
      Seen     : Manifest_Path_Sets.Set;

      procedure Check_Line (Raw : String; Number : Positive) is
         pragma Unreferenced (Number);
         Manifest_Path : constant String := Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
      begin
         if Manifest_Path = "" or else Starts_With (Manifest_Path, "#") then
            return;
         elsif Starts_With (Manifest_Path, "/") or else Contains (Manifest_Path, "..") then
            Put_Line
              (Standard_Error,
               Manifest & ": unsafe packaged resource path: " & Manifest_Path);
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
            raise Program_Error;
         elsif Seen.Contains (Manifest_Path) then
            Put_Line
              (Standard_Error,
               Manifest & ": duplicate packaged resource path: " & Manifest_Path);
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
            raise Program_Error;
         end if;

         Seen.Insert (Manifest_Path);

         if Manifest_Path = "bin/files" then
            return;
         elsif not Project_Tools.Files.File_Exists (Root & "/" & Manifest_Path) then
            Put_Line
              (Standard_Error,
               Manifest & ": missing packaged resource: " & Manifest_Path);
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
            raise Program_Error;
         end if;
      end Check_Line;
   begin
      For_Each_Line (Content, Check_Line'Access);
   end Check_Manifest_Entries;
