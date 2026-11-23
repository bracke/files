separate (Check_All)
   procedure Check_Path_Text_Calls is
      use Tokens;
      Aliases : constant String := Package_Aliases (File_System_Units);

      procedure Check_File (Path : String) is
         Toks : constant Token_List := Tokens_Of (Project_Tools.Files.Read_Raw_File (Path));
         Bad  : Boolean := False;

         --  Simple_Name of a search entry, named Directory_Entry, is no path's text.
         function Of_Search_Entry (Next : Positive) return Boolean is
           (Next + 2 <= Toks.Last_Index
            and then Is_Symbol (Toks (Next), "(")
            and then Is_Word (Toks (Next + 1), "directory_entry")
            and then Is_Symbol (Toks (Next + 2), "=>"));

         procedure Check_Name (Name : String; Next : Positive) is
         begin
            if Name in "ada.directories.containing_directory" | "ada.directories.compose"
              or else (Name = "ada.directories.simple_name" and then not Of_Search_Entry (Next))
            then
               Bad := True;
            end if;
         end Check_Name;
      begin
         For_Each_Resolved_Name (Toks, Aliases, File_System_Units, Check_Name'Access);
         if Bad then
            Report (Path & ": reads a path with Ada.Directories (Simple_Name, Containing_Directory, Compose);"
               & " use Files.IO.Fs_Primitives or Hostkit.Fs.Join");
         end if;
      end Check_File;
   begin
      for Item of Project_Tools.Files.List_Tree (Root & "/src", "*.ad?", Generated_Directories) loop
         Check_File (To_String (Item));
      end loop;
   end Check_Path_Text_Calls;
