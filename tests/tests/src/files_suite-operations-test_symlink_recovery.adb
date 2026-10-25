separate (Files_Suite.Operations)
   procedure Test_Symlink_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Target   : constant String := Join (Root, "link-target");
      Link     : constant String := Join (Root, "trash-link");
      Renamed  : constant String := Join (Root, "renamed-link");
      Trashed  : Files.Types.UString;
      Result   : Files.File_System.Mutation_Result;
      Paths    : Files.Types.String_Vectors.Vector;
      Model    : Files.Model.Window_Model;
      Step     : Files.Operations.Operation_Result;
      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Environment_Guard;
   begin
      Files_Suite.Support.Save (Environment, "XDG_DATA_HOME");
      Files_Suite.Support.Save (Environment, "FILES_TRASH_BACKEND");
      Reset_Root;
      Write_Binary_File (Target, "target");
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Join (Root, "link-data"));
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
      for Kind in 1 .. 4 loop
         if not Hostkit.Fs.Create_Link
           ((case Kind is
                when 1 => Target,
                when 2 => Join (Root, "missing-target"),
                when 3 => Files.File_System.Trash_Files_Directory,
                when others => Root), Link)
         then
            return;
         end if;
         Result := Files.File_System.Move_To_Trash (Link, Trashed);
         Assert (Result.Success and then Hostkit.Fs.Is_Link (To_String (Trashed)), "trash preserves the link itself");
         Assert (not Hostkit.Fs.Is_Link (Link), "trash removes the original link pathname");
         Assert (not Files.File_System.Move_To_Trash_Preflight (To_String (Trashed)).Success,
                 "an already-trashed link is identified by its own location");
         Result := Files.File_System.Restore_From_Trash (To_String (Trashed));
         Assert (Result.Success and then Hostkit.Fs.Is_Link (Link),
                 "restore uses the link pathname, including dangling links");
         Result := Files.File_System.Delete_Permanently (Link);
         Assert (Result.Success and then not Hostkit.Fs.Is_Link (Link), "permanent deletion removes dangling links");
         Files_Suite.Support.Assert_Equal
           (Project_Tools.Files.Read_Raw_File (Target),
            "target",
            "trashing, restoring and deleting never touch the target");
      end loop;
      if Hostkit.Fs.Create_Link (Join (Root, "missing-target"), Link) then
         declare
            Identity : constant String := Files.File_Identities.Token (Link);
            Planned : Files.File_System.Drop_Import_Result;
            Sources : Files.Types.String_Vectors.Vector;
            Output  : constant String := Join (Root, "link-copies");
         begin
            Assert (Identity /= "", "identify a dangling link before renaming it");
            Result := Files.File_System.Rename_Item (Link, Link);
            Assert (Result.Success and then Hostkit.Fs.Is_Link (Link),
                    "a no-op rename accepts a dangling link");
            Result := Files.File_System.Rename_Item (Link, Renamed);
            Assert (Result.Success, "rename moves a dangling link without following its missing target: renamed");
            Assert
              (Hostkit.Fs.Is_Link (Renamed),
               "rename moves a dangling link without following its missing target: new link present");
            Assert
              (not Hostkit.Fs.Is_Link (Link),
               "rename moves a dangling link without following its missing target: old link gone");
            Result := Files.File_System.Rename_Item (Renamed, Link, Identity);
            Assert (Result.Success and then Hostkit.Fs.Is_Link (Link),
                    "guarded rename restores the same dangling link by identity");
            Ada.Directories.Create_Directory (Output);
            Sources.Append (To_Unbounded_String (Link));
            Planned := Files.File_System.Plan_Drop_Import (Sources, Output);
            Assert (Planned.Success and then Planned.Plans.First_Element.Valid,
                    "drop planning accepts a dangling source link");
            Result := Files.File_System.Execute_Drop_Import (Planned.Plans);
            Assert (Result.Success and then Hostkit.Fs.Is_Link (Join (Output, "trash-link")),
                    "a dropped dangling link is copied as a link");
            declare
               Listing : constant Files.File_System.Directory_Load_Result :=
                 Files.File_System.Load_Directory (Output, Settings);
               Single : constant Files.File_System.Item_Load_Result :=
                 Files.File_System.Load_Item (Join (Output, "trash-link"), Settings);
            begin
               Assert (Listing.Success, "folder listings show dangling links as links: listed");
               Files_Suite.Support.Assert_Equal
                 (Natural (Listing.Items.Length),
                  1,
                  "folder listings show dangling links as links: one item");
               Assert
                 (Listing.Items.First_Element.Kind = Files.Types.Symlink_Item,
                  "folder listings show dangling links as links: listed as a link");
               Assert (Single.Success and then Single.Item.Kind = Files.Types.Symlink_Item,
                       "single-item loading accepts a dangling link");
               Files_Suite.Support.Assert_Equal
                 (Files.File_System.Directory_State (Output).Entry_Count,
                  1,
                  "refresh signatures count dangling links");
            end;
            declare
               Nested : constant String := Join (Output, "nested");
               Copied : constant String := Join (Root, "copied-link-tree");
            begin
               Ada.Directories.Create_Directory (Nested);
               Assert (Hostkit.Fs.Create_Link ("../missing", Join (Nested, "broken")),
                       "create a nested dangling-link fixture");
               Result := Files.File_System.Copy_Tree (Output, Copied);
               Assert (Result.Success, "recursive copies preserve every nested dangling link: copied");
               Assert
                 (Hostkit.Fs.Is_Link (Join (Copied, "trash-link")),
                  "recursive copies preserve every nested dangling link: top-level link kept");
               Assert
                 (Hostkit.Fs.Is_Link (Join (Join (Copied, "nested"), "broken")),
                  "recursive copies preserve every nested dangling link: nested link kept");
               Result := Files.File_System.Delete_Permanently (Copied);
               Assert (Result.Success and then not Ada.Directories.Exists (Copied),
                       "recursive deletion removes folders containing dangling links");
               Assert (Hostkit.Fs.Is_Link (Join (Nested, "broken")),
                       "deleting the copied tree preserves the source link");
            end;
         end;
         Files.Model.Initialize (Model, Root, Files.File_System.Item_Vectors.Empty_Vector, Root);
         Paths.Append (To_Unbounded_String (Link));
         Files.Model.Record_Undo
           (Model, Files.Model.Undo_Delete_Created, Paths, Files.Types.String_Vectors.Empty_Vector, Redoable => False);
         Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
         Assert (Step.Status = Files.Operations.Operation_Success and then not Hostkit.Fs.Is_Link (Link),
                 "Undo removes a created dangling link");
      end if;
   end Test_Symlink_Recovery;
