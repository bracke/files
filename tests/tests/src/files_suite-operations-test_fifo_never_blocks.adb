with Files.UI_Types;
with Files.Operation_Results;
with Files.Operation_Commands;
with Files.File_System.Thumbnails;
separate (Files_Suite.Operations)
   procedure Test_Fifo_Never_Blocks (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  Through the test's C helper: Windows has no mkfifo to link against.
      function Make_Fifo (Path : Interfaces.C.Strings.chars_ptr) return Interfaces.C.int
        with Import, Convention => C, External_Name => "files_test_make_fifo";
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Dir      : constant String := Join (Root, "with-fifo");
      Pipe     : constant String := Join (Dir, "pipe");
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Step     : Files.Operation_Results.Operation_Result;
      Made     : Boolean;
   begin
      if Hostkit.Host.Current = Hostkit.Host.Windows then
         Files_Suite.Support.Skip ("Test_Fifo_Never_Blocks", "Windows has no FIFOs");
         return;
      end if;
      Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Write_Binary_File (Join (Dir, "note.txt"), "needle");
      declare
         C_Pipe : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.New_String (Pipe);
      begin
         Made := Integer (Make_Fifo (C_Pipe)) = 0;
         Interfaces.C.Strings.Free (C_Pipe);
      end;
      if not Made then
         Files_Suite.Support.Skip ("Test_Fifo_Never_Blocks", "this host would not make a FIFO");
         return;
      end if;

      Load := Files.File_System.Load_Directory (Dir, Settings);
      Assert (Load.Success and then Natural (Load.Items.Length) = 2, "a folder holding a FIFO lists both entries");
      for Item of Load.Items loop
         if To_String (Item.Name) = "pipe" then
            Assert (Files.Quick_Look."/="
                      (Files.Operations.Prepare_Quick_Look (Item).Kind, Files.Quick_Look.Text_Content),
                    "Quick Look of a FIFO shows its card without reading it");
         end if;
      end loop;
      Assert (Files.File_System.Thumbnails.Generate_Thumbnail (Pipe, Join (Root, "thumbs")).Status
                /= Files.File_System.Thumbnails.Thumbnail_Generated,
              "a FIFO is never thumbnailed");

      Files.Model.Initialize (Model, Dir, Load.Items, Root);
      Files.Model.Set_Filter (Model, "needle");
      Step := Complete_Operation
        (Model, Settings, Files.Operation_Commands.Run_Search (Model, Settings, Files.UI_Types.Search_Contents));
      Assert (Step.Status = Files.Operation_Results.Operation_Success and then Files.Model.Item_Count (Model) = 1,
              "content search reads the file and passes the FIFO by");

      declare
         Copied : constant Files.File_System.Mutation_Result := Files.File_System.Copy_Tree (Dir, Join (Root, "copy"));
         pragma Unreferenced (Copied);
      begin
         Assert (Ada.Directories.Exists (Join (Dir, "note.txt")), "copying a tree with a FIFO returns, source intact");
      end;
      --  A FIFO cannot go into an archive: the folder still compresses, and
      --  the user is told what was left out.
      declare
         Parent : Files.Model.Window_Model;
         Listed : constant Files.File_System.Directory_Load_Result := Files.File_System.Load_Directory (Root, Settings);
      begin
         Files.Model.Initialize (Parent, Root, Listed.Items, Root);
         Select_Name (Parent, "with-fifo");
         Step := Complete_Operation
           (Parent, Settings,
            Files.Operation_Commands.Compress_Selected (Parent, Settings, Files.Operations.Zip_Archive));
         Assert (Step.Status = Files.Operation_Results.Operation_Success
                 and then Ada.Directories.Exists (Join (Root, "with-fifo.zip")),
                 "a folder holding a FIFO still compresses");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Last_Error_Key (Parent), "error.compress.special_skipped",
            "compressing says the FIFO was left out");
      end;
      --  Ada.Directories does not see a FIFO as a file to delete.
      GNAT.OS_Lib.Delete_File (Pipe, Made);
   end Test_Fifo_Never_Blocks;
