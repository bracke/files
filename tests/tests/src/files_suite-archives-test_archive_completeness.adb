with Files.Operations.History.Testing;
with Files.Model.Jobs;
with Files.Operations.History;
with Files.Operations.Navigation;
with Files_Suite.Listings;
with Files.Operation_Results;
with Files.Settings.Path_References;
with Files_Suite.Support.Guards;
with Files_Suite.Support.Disk;
separate (Files_Suite.Archives)
   procedure Test_Archive_Completeness (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : aliased Files.Model.Window_Model;
      Paste : Files_Suite.Support.Guards.Paste_Guard (Model'Access);
      pragma Unreferenced (Paste);
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operation_Results.Operation_Result;
   begin
      for Background in Boolean loop
         Reset_Root;
         Write_Binary_File (Join (Root, "a.txt"), "a bytes");
         Write_Binary_File (Join (Root, "b.txt"), "b bytes");
         Load := Files_Suite.Listings.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Operations.History.Testing.Clear_Undo (Model);
         Files.Model.Selection.Select_All_Visible (Model);
         Files.Model.Jobs.Set_Background_Transfers (Model, Background);
         Ada.Directories.Delete_File (Join (Root, "b.txt"));
         Step := Complete_Operation
           (Model, Settings,
            Operation_Commands.Compress_Selected (Model, Settings, Files.Operations.Archives.Zip_Archive));
         declare
            Context : constant String :=
              "a missing selected source cannot produce a successful incomplete archive or Undo entry";
         begin
            Files_Suite.Support.Assert_Equal
              (Step.Status, Files.Operation_Results.Operation_Failed, Context & ": status");
            Files_Suite.Support.Assert_Equal
              (To_String (Step.Error_Key), "error.compress.failed", Context & ": result error key");
            Files_Suite.Support.Assert_Equal
              (Files.Model.Last_Error_Key (Model), "error.compress.failed", Context & ": model error key");
            Assert (not Ada.Directories.Exists (Join (Root, "a.zip")), Context & ": no archive");
            Assert (not Files.Model.History.Undo_Available (Model), Context & ": no Undo entry");
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
         Files.Settings.Path_References.Note_Recent (Settings, Join (Join (Root, "one"), "same.txt"));
         Files.Settings.Path_References.Note_Recent (Settings, Join (Join (Root, "two"), "same.txt"));
         Files.Model.Initialize (Model, Root, Files.Items.Item_Vectors.Empty_Vector, Root);
         Files.Operations.History.Testing.Clear_Undo (Model);
         Files.Model.Jobs.Set_Background_Transfers (Model, Background);
         Files_Suite.Support.Discard (Files.Operations.Navigation.Navigate_Recent (Model, Settings));
         Files.Model.Selection.Select_All_Visible (Model);
         Step := Complete_Operation
           (Model, Settings,
            Operation_Commands.Compress_Selected (Model, Settings, Files.Operations.Archives.Zip_Archive));
         --  Two inputs with one name are both kept: the second as "same 2.txt",
         --  so neither overwrites nor silently replaces the other.
         Files_Suite.Support.Assert_Equal
           (Step.Status, Files.Operation_Results.Operation_Success, "two inputs sharing a name are archived together");
         declare
            --  Beside the first selected input: Recent lists the newest first.
            Archive : constant String :=
              (if Ada.Directories.Exists (Join (Join (Root, "two"), "same.zip"))
               then Join (Join (Root, "two"), "same.zip")
               else Join (Join (Root, "one"), "same.zip"));
            Out_Dir : constant String := Join (Root, "unpacked");
            Status  : Zlib.Status_Code;
            use type Zlib.Status_Code;
         begin
            Ada.Directories.Create_Path (Out_Dir);
            Zlib.Extract_Archive_File_To_Directory (Archive, Out_Dir, "", Status);
            Assert (Status = Zlib.Ok, "the archive beside the first input reads back: " & Archive);
            Assert (Ada.Directories.Exists (Join (Out_Dir, "same.txt"))
                    and then Ada.Directories.Exists (Join (Out_Dir, "same 2.txt"))
                    and then Project_Tools.Files.Read_Raw_File (Join (Out_Dir, "same.txt"))
                             /= Project_Tools.Files.Read_Raw_File (Join (Out_Dir, "same 2.txt")),
                    "duplicate archive entry names cannot overwrite or silently replace a selected input");
         end;
         Await_View (Model, Settings);
      end loop;
      --  The archive writers cannot hold a symbolic link: the archive is still
      --  made, and the user is told the link was left out.
      for Background in Boolean loop
         Reset_Root;
         Ada.Directories.Create_Path (Join (Root, "bag"));
         Write_Binary_File (Join (Join (Root, "bag"), "keep.txt"), "kept");
         if not Files_Suite.Support.Disk.Create_Symlink ("keep.txt", Join (Join (Root, "bag"), "pointer")) then
            Files_Suite.Support.Disk.Link_Not_Made ("Test_Archive_Completeness");
            exit;
         end if;
         Settings := Files.Settings.Default_Settings;
         Load := Files_Suite.Listings.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Operations.History.Testing.Clear_Undo (Model);
         Select_Name (Model, "bag");
         Files.Model.Jobs.Set_Background_Transfers (Model, Background);
         Step := Complete_Operation
           (Model, Settings,
            Operation_Commands.Compress_Selected (Model, Settings, Files.Operations.Archives.Zip_Archive));
         Assert (Step.Status = Files.Operation_Results.Operation_Success
                 and then Ada.Directories.Exists (Join (Root, "bag.zip")),
                 "a folder holding a link still compresses");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Last_Error_Key (Model),
            "error.compress.links_skipped",
            "compressing says the link was left out"
            & (if Background then " (background)" else " (foreground)"));
         Await_View (Model, Settings);
      end loop;
      --  A dangling link inside a folder is still a link left out: the
      --  listing reports it missing (its kind follows the link), and it was
      --  once dropped without the notice.
      Reset_Root;
      Ada.Directories.Create_Path (Join (Root, "bag"));
      Write_Binary_File (Join (Join (Root, "bag"), "keep.txt"), "kept");
      if Files_Suite.Support.Disk.Create_Symlink ("gone.txt", Join (Join (Root, "bag"), "dangling")) then
         Settings := Files.Settings.Default_Settings;
         Load := Files_Suite.Listings.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Operations.History.Testing.Clear_Undo (Model);
         Select_Name (Model, "bag");
         Files.Model.Jobs.Set_Background_Transfers (Model, False);
         Step := Complete_Operation
           (Model, Settings,
            Operation_Commands.Compress_Selected (Model, Settings, Files.Operations.Archives.Zip_Archive));
         Assert (Step.Status = Files.Operation_Results.Operation_Success
                 and then Ada.Directories.Exists (Join (Root, "bag.zip")),
                 "a folder holding a dangling link still compresses");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Last_Error_Key (Model),
            "error.compress.links_skipped",
            "compressing says the dangling link was left out");
         Await_View (Model, Settings);
      else
         Files_Suite.Support.Disk.Link_Not_Made ("Test_Archive_Completeness");
      end if;
      if Hostkit.Host.Current /= Hostkit.Host.Windows then
         for Background in Boolean loop
            for Format in Files.Operations.Archives.Archive_Format loop
               Reset_Root;
               Ada.Directories.Create_Path (Join (Root, "bag"));
               Write_Binary_File (Join (Join (Root, "bag"), "notes:2024.txt"), "colon bytes");
               Settings := Files.Settings.Default_Settings;
               Load := Files_Suite.Listings.Load_Directory (Root, Settings);
               Files.Model.Initialize (Model, Root, Load.Items, Root);
               Files.Operations.History.Testing.Clear_Undo (Model);
               Files.Model.Jobs.Set_Background_Transfers (Model, Background);
               Select_Name (Model, "bag");
               Step := Complete_Operation
                 (Model, Settings, Operation_Commands.Compress_Selected (Model, Settings, Format));
               declare
                  Context : constant String :=
                    "a name an archive cannot store is reported as such, not as a generic failure";
               begin
                  Files_Suite.Support.Assert_Equal
                    (Step.Status, Files.Operation_Results.Operation_Failed, Context & ": status");
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
   end Test_Archive_Completeness;
