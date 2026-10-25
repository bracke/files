separate (Files_Suite.Operations)
   procedure Test_Search_Read_Errors (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Mutation : Files.File_System.Mutation_Result;
      Denied : Unbounded_String;
      Read_Ok : Boolean;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux then
         Files_Suite.Support.Skip ("Test_Search_Read_Errors", "needs Linux");
         return;
      end if;
      for Background in Boolean loop
         for Contents in Boolean loop
            for Case_Id in 1 .. (if Contents then 3 else 2) loop
               Reset_Root;
               Ada.Directories.Create_Directory (Join (Root, "sub"));
               Write_Binary_File (Join (Root, "needle.txt"), "needle bytes");
               Write_Binary_File (Join (Join (Root, "sub"), "needle.txt"), "needle bytes");
               Load := Files.File_System.Load_Directory (Root, Settings);
               Files.Model.Initialize (Model, Root, Load.Items, Root);
               Files.Model.Set_Background_Transfers (Model, Background);
               Files.Model.Set_Filter (Model, "needle");
               Denied := To_Unbounded_String
                 ((case Case_Id is when 1 => Root, when 2 => Join (Root, "sub"),
                   when others => Join (Root, "needle.txt")));
               Mutation := Files.File_System.Set_Permissions (To_String (Denied), 0);
               Assert (Mutation.Success, "make the search input unreadable");
               Step := (if Contents then Files.Operations.Run_Content_Search (Model, Settings)
                        else Files.Operations.Run_Recursive_Search (Model, Settings));
               Step := Complete_Operation (Model, Settings, Step);
               Mutation := Files.File_System.Set_Permissions (To_String (Denied), 8#755#);
               Files_Suite.Support.Assert_Equal
                 (Step.Status,
                  Files.Operations.Operation_Failed,
                  "read failures preserve the listing and report an error instead of partial success: status");
               Files_Suite.Support.Assert_Equal
                 (Files.Model.Item_Count (Model),
                  2,
                  "read failures preserve the listing and report an error instead of partial success: item count");
               Assert
                 (not Files.Model.Search_Results_Are_Active (Model),
                  "read failures preserve the listing and report an error instead of partial success"
                  & ": results inactive");
               Files_Suite.Support.Assert_Equal
                 (To_String (Step.Error_Key),
                  (if Case_Id = 1 then "error.directory.load" else "error.search.failed"),
                  "read failures preserve the listing and report an error instead of partial success: error key");
            end loop;
         end loop;
      end loop;
      Write_Binary_File (Join (Root, "empty.txt"), "");
      declare
         Text : constant String := Files.File_System.Read_Preview_Text
           (Join (Root, "empty.txt"), 100, Read_Ok);
      begin
         Assert (Read_Ok and then Text = "", "an empty readable file is a successful read");
      end;
      declare
         Text : constant String := Files.File_System.Read_Preview_Text
           (Join (Root, "missing.txt"), 100, Read_Ok);
      begin
         Assert (not Read_Ok and then Text = "", "an open failure is distinct from an empty file");
      end;
      declare
         Text : constant String := Files.File_System.Read_Preview_Text
           (Join (Root, "empty.txt") & ASCII.NUL & "ignored", 100, Read_Ok);
      begin
         Assert
           (not Read_Ok and then Text = "",
            "preview paths containing NUL are rejected rather than truncated by the native opener");
      end;
      Write_Binary_File (Join (Root, "preview-target.txt"), "private bytes");
      if Create_Symlink
           (Join (Root, "preview-target.txt"), Join (Root, "preview-link.txt"))
      then
         declare
            Text : constant String := Files.File_System.Read_Preview_Text
              (Join (Root, "preview-link.txt"), 100, Read_Ok);
         begin
            Assert
              (not Read_Ok and then Text = "",
               "preview reads refuse a symbolic link instead of following it");
         end;
      else
         Files_Suite.Support.Link_Not_Made ("Test_Search_Read_Errors", Files_Suite.Support.Symbolic_Link);
      end if;
      declare
         Text : constant String := Files.File_System.Read_Preview_Text
           ("/dev/null", 100, Read_Ok);
      begin
         Assert
           (not Read_Ok and then Text = "",
            "preview reads refuse a special file without treating it as empty");
      end;
   exception
      when others =>
         if Length (Denied) > 0 then
            Mutation := Files.File_System.Set_Permissions (To_String (Denied), 8#755#);
         end if;
         Files.Model.Clear_Paste_Execution (Model);
         raise;
   end Test_Search_Read_Errors;
