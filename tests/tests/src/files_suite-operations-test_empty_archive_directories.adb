separate (Files_Suite.Operations)
   procedure Test_Empty_Archive_Directories (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Zlib.Status_Code;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Status : Zlib.Status_Code;
      Archive : Unbounded_String;
      Verify : constant String := Join (Root, "verify");
   begin
      for Background in Boolean loop
         for Format in Files.Operations.Archive_Format loop
            for Empty_Only in Boolean loop
               Reset_Root;
               Ada.Directories.Create_Path (Join (Join (Join (Root, "bag"), "empty"), "nested"));
               Ada.Directories.Create_Path (Join (Join (Root, "bag"), "other empty"));
               if not Empty_Only then
                  Write_Binary_File (Join (Join (Root, "bag"), "data.txt"), "payload bytes");
               end if;
               Load := Files.File_System.Load_Directory (Root, Settings);
               Files.Model.Initialize (Model, Root, Load.Items, Root);
               Files.Model.Clear_Undo (Model);
               Files.Model.Set_Background_Transfers (Model, Background);
               Select_Name (Model, "bag");
               Step := Complete_Operation
                 (Model, Settings, Files.Operations.Compress_Selected (Model, Settings, Format));
               Archive := To_Unbounded_String
                 (Join (Root, (if Format = Files.Operations.Zip_Archive then "bag.zip" else "bag.7z")));
               Assert (Step.Status = Files.Operations.Operation_Success
                       and then Ada.Directories.Exists (To_String (Archive)),
                       "mixed and directory-only selections produce successful ZIP and 7z archives");
               Ada.Directories.Create_Directory (Verify);
               Zlib.Extract_Archive_File_To_Directory (To_String (Archive), Verify, "", Status);
               Assert (Status = Zlib.Ok
                       and then Ada.Directories.Exists (Join (Join (Join (Verify, "bag"), "empty"), "nested"))
                       and then Ada.Directories.Exists (Join (Join (Verify, "bag"), "other empty"))
                       and then (Empty_Only or else
                                 File_Has_Bytes (Join (Join (Verify, "bag"), "data.txt"), "payload bytes")),
                       "round-trip extraction preserves every empty directory and file payload");
               Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
               Await_View (Model, Settings);
               Assert (Step.Status = Files.Operations.Operation_Success
                       and then not Ada.Directories.Exists (To_String (Archive))
                       and then Ada.Directories.Exists (Join (Join (Join (Root, "bag"), "empty"), "nested")),
                       "Undo removes the archive while preserving its source directories");
            end loop;
         end loop;
      end loop;
   exception
      when others => Files.Model.Clear_Paste_Execution (Model); Files.Refresh_Jobs.Cancel (Model); raise;
   end Test_Empty_Archive_Directories;
