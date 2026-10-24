separate (Files_Suite.Operations)
   procedure Test_Recursive_Folder_Size (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Tree     : constant String := Join (Root, "tree");
      Nested   : constant String := Join (Tree, "nested");
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Size     : Files.File_System.Directory_Size_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Nested);
      Write_Binary_File (Join (Tree, "a.txt"), "12345");   --  5 bytes
      Write_Binary_File (Join (Tree, "b.txt"), "678");     --  3 bytes
      Write_Binary_File (Join (Nested, "c.txt"), "90");    --  2 bytes

      Size := Files.File_System.Directory_Size (Tree);
      Assert (Size.Available, "recursive size is available for a real directory");
      Assert (Size.Total_Bytes = 10, "recursive size sums all descendant file bytes");
      Assert (Size.File_Count = 3, "recursive size counts every descendant regular file");
      Assert (not Size.Capped, "a small tree does not trip the entry/depth cap");

      --  A symlink cycle must not hang or be followed. Measure with the loop
      --  present, then remove the link before any assertion so a failure cannot
      --  leave a self-referential tree that later cleanup cannot delete.
      if Files_Suite.Support.Create_Symlink (Tree, Join (Tree, "loop")) then
         declare
            Guarded : constant Files.File_System.Directory_Size_Result :=
              Files.File_System.Directory_Size (Tree);
         begin
            --  A link to a directory is a directory entry on Windows, so
            --  Delete_File will not take it. Delete_Tree removes a link without
            --  following it, whichever kind of entry the platform made it.
            Project_Tools.Files.Delete_Tree (Join (Tree, "loop"));
            Assert (Guarded.Available, "size walk completes despite a symlink cycle");
            Assert (Guarded.Total_Bytes = 10, "symlinked directory is not descended into");
         end;
      end if;

      declare
         Root_Link : constant String := Join (Root, "size-root-link");
      begin
         if Files_Suite.Support.Create_Symlink (Tree, Root_Link) then
            declare
               Guarded : constant Files.File_System.Directory_Size_Result :=
                 Files.File_System.Directory_Size (Root_Link);
            begin
               Project_Tools.Files.Delete_Tree (Root_Link);
               Assert
                 (not Guarded.Available
                  and then Guarded.Total_Bytes = 0
                  and then Guarded.Item_Count = 0,
                  "folder sizing refuses a symlink supplied as its root");
            end;
         end if;
      end;

      --  A root that cannot be enumerated is not an empty directory.  Gate the
      --  assertion on the host actually denying the search (for example, a
      --  privileged test process may still enumerate mode 000).
      declare
         Locked      : constant String := Join (Root, "locked-size-root");
         Search      : Ada.Directories.Search_Type;
         Dir_Item    : Ada.Directories.Directory_Entry_Type;
         Started     : Boolean := False;
         Denied      : Boolean := False;
         Mutation    : Files.File_System.Mutation_Result;
         Guarded     : Files.File_System.Directory_Size_Result;
      begin
         Ada.Directories.Create_Directory (Locked);
         Write_Binary_File (Join (Locked, "hidden"), "not empty");
         Mutation := Files.File_System.Set_Permissions (Locked, 0);
         if Mutation.Success then
            begin
               Ada.Directories.Start_Search (Search, Locked, "");
               Started := True;
               if Ada.Directories.More_Entries (Search) then
                  Ada.Directories.Get_Next_Entry (Search, Dir_Item);
               end if;
               Ada.Directories.End_Search (Search);
               Started := False;
            exception
               when others =>
                  Denied := True;
                  if Started then
                     begin
                        Ada.Directories.End_Search (Search);
                     exception
                        when others => null;
                     end;
                     Started := False;
                  end if;
            end;

            Guarded := Files.File_System.Directory_Size (Locked);
            Mutation := Files.File_System.Set_Permissions (Locked, 8#755#);
            Assert (Mutation.Success, "restore the folder-size test root mode");
            if Denied then
               Assert
                 (not Guarded.Available
                  and then Guarded.Total_Bytes = 0
                  and then Guarded.File_Count = 0
                  and then Guarded.Item_Count = 0
                  and then not Guarded.Capped,
                  "an unreadable size root is unavailable, not an empty measurement");
            end if;
         end if;
         Project_Tools.Files.Delete_Tree (Locked);
      exception
         when others =>
            if Started then
               begin
                  Ada.Directories.End_Search (Search);
               exception
                  when others => null;
               end;
            end if;
            Mutation := Files.File_System.Set_Permissions (Locked, 8#755#);
            Project_Tools.Files.Delete_Tree (Locked);
            raise;
      end;

      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "tree");
      Files.Model.Toggle_Info_Pane (Model);
      Files.Model.Cancel_Folder_Scan (Model);
      Files.Operations.Update_Folder_Size (Model, Settings);

      --  The measurement now runs in a helper off the UI path; drive it to
      --  completion and publish it, as the frame loop would, before snapshotting.
      declare
         Done_Path : Ada.Strings.Unbounded.Unbounded_String;
         Measured  : Files.File_System.Directory_Size_Result;
         Available : Boolean := False;
      begin
         loop
            Files.Model.Poll_Folder_Sizes (Model);
            Available := not Files.Model.Folder_Scan_Is_Active (Model);
            exit when Available or else not Files.Model.Folder_Scan_Is_Active (Model);
            delay 0.001;
         end loop;
      end;

      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Frame    : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands (Snapshot, 1400, 1000);
         Label    : constant String := Files.Localization.Text ("info.folder_size");
         Found    : Boolean := False;
      begin
         Assert
           (Snapshot.Selected_Info.Element (1).Folder_Size_Available,
            "the info snapshot carries the measured folder size");
         Assert
           (Snapshot.Selected_Info.Element (1).Folder_Size_Bytes = 10,
            "the info snapshot folder-size total is correct");
         for Command of Frame.Text loop
            if Ada.Strings.Fixed.Index (To_String (Command.Text), Label) > 0 then
               Found := True;
            end if;
         end loop;
         Assert (Found, "the info pane emits the folder-size row for a selected directory");
      end;
   end Test_Recursive_Folder_Size;
