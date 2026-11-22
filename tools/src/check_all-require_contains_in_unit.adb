separate (Check_All)
   procedure Require_Contains_In_Unit
     (Base_Path : String;
      Pattern   : String;
      Message   : String)
   is
      Dir  : constant String := Ada.Directories.Containing_Directory (Base_Path);
      Stem : constant String := Ada.Directories.Base_Name (Base_Path);

      function Holds (Path : String) return Boolean is
        (Project_Tools.Files.File_Exists (Path)
         and then Ada.Strings.Fixed.Index
                    (Code_Of
                       (To_String (Project_Tools.Text.Read_Text_File (Path)), Blank_Strings => not Quotes (Pattern)),
                     Pattern) /= 0);
   begin
      if Holds (Base_Path) then
         return;
      end if;

      --  Only a body has subunits; a spec (.ads) is covered on its own.
      if Ada.Directories.Extension (Base_Path) = "adb" then
         for Subunit of Project_Tools.Files.List_Tree (Dir, Stem & "-?*.adb", Generated_Directories) loop
            if Holds (To_String (Subunit)) then
               return;
            end if;
         end loop;
      end if;
      Report (Base_Path & ": " & Message);
   end Require_Contains_In_Unit;
