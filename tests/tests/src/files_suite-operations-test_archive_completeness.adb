separate (Files_Suite.Operations)
   procedure Test_Archive_Completeness (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
   begin
      for Background in Boolean loop
         Reset_Root;
         Write_Binary_File (Join (Root, "a.txt"), "a bytes");
         Write_Binary_File (Join (Root, "b.txt"), "b bytes");
         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Operations.Clear_Undo (Model);
         Files.Model.Select_All_Visible (Model);
         Files.Model.Set_Background_Transfers (Model, Background);
         Ada.Directories.Delete_File (Join (Root, "b.txt"));
         Step := Complete_Operation
           (Model, Settings, Files.Operations.Compress_Selected (Model, Settings, Files.Operations.Zip_Archive));
         declare
            Context : constant String :=
              "a missing selected source cannot produce a successful incomplete archive or Undo entry";
         begin
            Files_Suite.Support.Assert_Equal (Step.Status, Files.Operations.Operation_Failed, Context & ": status");
            Files_Suite.Support.Assert_Equal
              (To_String (Step.Error_Key), "error.compress.failed", Context & ": result error key");
            Files_Suite.Support.Assert_Equal
              (Files.Model.Last_Error_Key (Model), "error.compress.failed", Context & ": model error key");
            Assert (not Ada.Directories.Exists (Join (Root, "a.zip")), Context & ": no archive");
            Assert (not Files.Model.Undo_Available (Model), Context & ": no Undo entry");
         end;
         Await_View (Model, Settings);
      end loop;
      for Background in Boolean loop
         Reset_Root;
         Ada.Directories.Create_Path (Join (Root, "one"));
         Ada.Directories.Create_Path (Join (Root, "two"));
         Write_Binary_File (Join (Join (Root, "one"), "same.txt"), "first source");
         Write_Binary_File (Join (Join (Root, "two"), "same.txt"), "second source");
         Settings := Files.Settings.Default_Settings;
         Files.Settings.Note_Recent (Settings, Join (Join (Root, "one"), "same.txt"));
         Files.Settings.Note_Recent (Settings, Join (Join (Root, "two"), "same.txt"));
         Files.Model.Initialize (Model, Root, Files.File_System.Item_Vectors.Empty_Vector, Root);
         Files.Operations.Clear_Undo (Model);
         Files.Model.Set_Background_Transfers (Model, Background);
         Step := Files.Operations.Navigate_Recent (Model, Settings);
         Files.Model.Select_All_Visible (Model);
         Step := Complete_Operation
           (Model, Settings, Files.Operations.Compress_Selected (Model, Settings, Files.Operations.Zip_Archive));
         Assert (Step.Status = Files.Operations.Operation_Failed
                 and then not Ada.Directories.Exists (Join (Join (Root, "two"), "same.zip")),
                 "duplicate archive entry names cannot overwrite or silently replace a selected input");
         Await_View (Model, Settings);
      end loop;
      --  The archive writers cannot hold a symbolic link: the archive is still
      --  made, and the user is told the link was left out.
      for Background in Boolean loop
         Reset_Root;
         Ada.Directories.Create_Path (Join (Root, "bag"));
         Write_Binary_File (Join (Join (Root, "bag"), "keep.txt"), "kept");
         exit when not Files_Suite.Support.Create_Symlink ("keep.txt", Join (Join (Root, "bag"), "pointer"));
         Settings := Files.Settings.Default_Settings;
         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Operations.Clear_Undo (Model);
         Select_Name (Model, "bag");
         Files.Model.Set_Background_Transfers (Model, Background);
         Step := Complete_Operation
           (Model, Settings, Files.Operations.Compress_Selected (Model, Settings, Files.Operations.Zip_Archive));
         Assert (Step.Status = Files.Operations.Operation_Success
                 and then Ada.Directories.Exists (Join (Root, "bag.zip")),
                 "a folder holding a link still compresses");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Last_Error_Key (Model),
            "error.compress.links_skipped",
            "compressing says the link was left out"
            & (if Background then " (background)" else " (foreground)"));
         Await_View (Model, Settings);
      end loop;
      if Hostkit.Host.Current /= Hostkit.Host.Windows then
         for Background in Boolean loop
            for Format in Files.Operations.Archive_Format loop
               Reset_Root;
               Ada.Directories.Create_Path (Join (Root, "bag"));
               Write_Binary_File (Join (Join (Root, "bag"), "notes:2024.txt"), "colon bytes");
               Settings := Files.Settings.Default_Settings;
               Load := Files.File_System.Load_Directory (Root, Settings);
               Files.Model.Initialize (Model, Root, Load.Items, Root);
               Files.Operations.Clear_Undo (Model);
               Files.Model.Set_Background_Transfers (Model, Background);
               Select_Name (Model, "bag");
               Step := Complete_Operation
                 (Model, Settings, Files.Operations.Compress_Selected (Model, Settings, Format));
               declare
                  Context : constant String :=
                    "a name an archive cannot store is reported as such, not as a generic failure";
               begin
                  Files_Suite.Support.Assert_Equal
                    (Step.Status, Files.Operations.Operation_Failed, Context & ": status");
                  Files_Suite.Support.Assert_Equal
                    (To_String (Step.Error_Key), "error.compress.unportable_name", Context & ": result error key");
                  Files_Suite.Support.Assert_Equal
                    (Files.Model.Last_Error_Key (Model),
                     "error.compress.unportable_name",
                     Context & ": model error key");
                  Assert (not Ada.Directories.Exists (Join (Root, "bag.zip")), Context & ": no zip archive");
                  Assert (not Ada.Directories.Exists (Join (Root, "bag.7z")), Context & ": no 7z archive");
               end;
               Await_View (Model, Settings);
            end loop;
         end loop;
      end if;
   exception
      when others => Files.Model.Clear_Paste_Execution (Model); Files.Refresh_Jobs.Cancel (Model); raise;
   end Test_Archive_Completeness;
