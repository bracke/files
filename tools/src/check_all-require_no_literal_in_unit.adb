separate (Check_All)
   procedure Require_No_Literal_In_Unit
     (Base_Path : String;
      Text      : String;
      Message   : String)
   is
      use Tokens;

      Dir  : constant String := Ada.Directories.Containing_Directory (Base_Path);
      Stem : constant String := Ada.Directories.Base_Name (Base_Path);

      procedure Scan (Path : String) is
      begin
         for Item of Tokens_Of (Project_Tools.Files.Read_Raw_File (Path), Preserve_Case => True) loop
            if Item.Kind = Literal and then Ada.Strings.Fixed.Index (To_String (Item.Text), Text) > 0 then
               Report (Path & ":" & Ada.Strings.Fixed.Trim (Item.Line'Image, Ada.Strings.Left) & ": " & Message);
               return;
            end if;
         end loop;
      end Scan;
   begin
      if not Ada.Directories.Exists (Base_Path) then
         Report (Base_Path & ": guarded unit no longer exists; point the guard at where the code went: " & Message);
         return;
      end if;
      Scan (Base_Path);
      if Ada.Directories.Extension (Base_Path) = "adb" then
         for Member of Project_Tools.Files.List_Tree (Dir, Stem & "-?*.adb", Generated_Directories) loop
            Scan (To_String (Member));
         end loop;
      end if;
   end Require_No_Literal_In_Unit;
