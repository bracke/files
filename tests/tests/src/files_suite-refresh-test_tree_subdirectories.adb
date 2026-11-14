separate (Files_Suite.Refresh)
   procedure Test_Tree_Subdirectories (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;

      function Folders (Name : String; Kind : Files.Types.Item_Kind) return Boolean is
        (Name'Length > 0 and then Kind = Files.Types.Directory_Item);
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Join (Root, "beta"));
      Ada.Directories.Create_Path (Join (Root, "Alpha"));
      Ada.Directories.Create_Path (Join (Root, ".hidden"));
      Write_File (Join (Root, "file.txt"), "x");
      Write_File (Join (Join (Root, "beta"), "inside.txt"), "longer content");
      declare
         Linked : constant Boolean := Hostkit.Fs.Create_Link (Join (Root, "beta"), Join (Root, "link-to-beta"));
         pragma Unreferenced (Linked);
      begin
         --  The tree's lean listing names the folders a full listing does,
         --  in the same order, for every sort and hidden setting.
         for Hidden in Boolean loop
            for Field in Files.Types.Sort_Field loop
               for Ascending in Boolean loop
                  declare
                     Options : constant Files.Types.Listing_Options :=
                       (Show_Hidden => Hidden, Sort_Field => Field, Sort_Ascending => Ascending);
                     Full : constant Files.File_System.Directory_Load_Result :=
                       Files.File_System.Load_Directory_Filtered (Root, Settings, Options, Folders'Access);
                     Lean : constant Files.File_System.Directory_Load_Result :=
                       Files.File_System.Load_Subdirectories (Root, Settings, Options);
                     Context : constant String :=
                       Hidden'Image & " " & Files.Types.Sort_Field'Image (Field) & Ascending'Image;
                  begin
                     Assert (Full.Success and then Lean.Success, "both list the folder: " & Context);
                     Files_Suite.Support.Assert_Equal
                       (Natural (Lean.Items.Length), Natural (Full.Items.Length), "as many folders: " & Context);
                     for Index in Full.Items.First_Index .. Full.Items.Last_Index loop
                        Files_Suite.Support.Assert_Equal
                          (To_String (Lean.Items (Index).Full_Path), To_String (Full.Items (Index).Full_Path),
                           "the same folder in place" & Index'Image & ": " & Context);
                     end loop;
                     Files_Suite.Support.Assert_Equal
                       (Natural (Lean.Items.Length), (if Hidden then 3 else 2),
                        "files and links to folders are not subfolders: " & Context);
                  end;
               end loop;
            end loop;
         end loop;
      end;
      Project_Tools.Files.Delete_Tree (Join (Root, "beta"));
   end Test_Tree_Subdirectories;
