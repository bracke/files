separate (Check_All.Check_Packaging_Metadata)
   procedure Check_Staged_Manifest_Entries is
      Manifest : constant String := Root & "/share/files/package.manifest";
      Content  : constant String := To_String (Project_Tools.Text.Read_Text_File (Manifest));

      procedure Check_Line (Raw : String) is
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
            Put_Line
              (Standard_Error,
               "staged install is missing manifest resource: " & Manifest_Path);
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
            raise Program_Error;
         end if;
      end Check_Line;
   begin
      if Content = "" then
         return;
      end if;

      declare
         Line_Start : Positive := Content'First;
      begin
         for Index in Content'Range loop
            if Content (Index) = ASCII.LF then
               Check_Line (Content (Line_Start .. Index - 1));
               Line_Start := Index + 1;
            end if;
         end loop;

         if Line_Start <= Content'Last then
            Check_Line (Content (Line_Start .. Content'Last));
         end if;
      end;
   end Check_Staged_Manifest_Entries;
