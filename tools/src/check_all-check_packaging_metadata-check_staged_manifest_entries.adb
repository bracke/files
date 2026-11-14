separate (Check_All.Check_Packaging_Metadata)
   procedure Check_Staged_Manifest_Entries is
      Manifest : constant String := Root & "/share/files/package.manifest";
      Content  : constant String := To_String (Project_Tools.Text.Read_Text_File (Manifest));

      procedure Check_Line (Raw : String; Number : Positive) is
         pragma Unreferenced (Number);
         Manifest_Path : constant String := Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
      begin
         if Manifest_Path = ""
           or else Starts_With (Manifest_Path, "#")
           or else Manifest_Path = "bin/files"
         then
            return;
         elsif Starts_With (Manifest_Path, "share/")
           and then not Project_Tools.Files.File_Exists (Stage & "/" & Manifest_Path)
         then
            Report ("staged install is missing manifest resource: " & Manifest_Path);
         end if;
      end Check_Line;
   begin
      For_Each_Line (Content, Check_Line'Access);
   end Check_Staged_Manifest_Entries;
