separate (Files_Suite.Operations)
   procedure Test_Undo_Same_Size_Edits (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Source : constant String := Join (Root, "original");
      Dest : constant String := Join (Root, "original (copy)");
      Old_Token : Unbounded_String;
   begin
      for Background in Boolean loop
         Reset_Root;
         Write_Binary_File (Source, "copied bytes");
         GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp
           (Source, GNAT.OS_Lib.GM_Time_Of (2020, 1, 2, 3, 4, 5));
         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Operations.Clear_Undo (Model);
         Files.Model.Set_Background_Transfers (Model, Background);
         Select_Name (Model, "original");
         Step := Complete_Operation (Model, Settings, Files.Operations.Duplicate_Selected (Model, Settings));
         Await_View (Model, Settings);
         Assert (Step.Status = Files.Operations.Operation_Success
                 and then Files.File_System.Tree_Revision (Dest) /= "",
                 "a copied regular file has a recorded revision");
         Old_Token := To_Unbounded_String (Files.File_Identities.Token (Dest));
         declare
            Stamp : constant GNAT.OS_Lib.OS_Time := GNAT.OS_Lib.File_Time_Stamp (Dest);
            Metadata : constant String := Files.File_Identities.Revision (Dest, False);
            Snapshot : constant String := Files.File_System.Tree_Revision (Dest);
         begin
            Write_Binary_File (Dest, "edited bytes");
            GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp (Dest, Stamp);
            Files_Suite.Support.Assert_Equal
              (Files.File_Identities.Token (Dest),
               To_String (Old_Token),
               "a same-size edit with restored mtime keeps its old metadata but changes its content digest"
               & ": identity token");
            Assert
              (Files.File_Identities.Revision (Dest, False) = Metadata,
               "a same-size edit with restored mtime keeps its old metadata but changes its content digest"
               & ": metadata revision kept");
            Assert
              (Files.File_System.Tree_Revision (Dest) /= Snapshot,
               "a same-size edit with restored mtime keeps its old metadata but changes its content digest"
               & ": content digest changed");
            Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Await_View (Model, Settings);
            Files_Suite.Support.Assert_Equal
              (Step.Status,
               Files.Operations.Operation_Failed,
               "Undo retains a same-size edited copy and its retryable action: status");
            Assert
              (Files.Model.Undo_Available (Model),
               "Undo retains a same-size edited copy and its retryable action: undo kept");
            Assert
              (File_Has_Bytes (Dest, "edited bytes"),
               "Undo retains a same-size edited copy and its retryable action: edited bytes kept");
         end;
         Reset_Root;
         Ada.Directories.Create_Directory (Source);
         Write_Binary_File (Join (Source, "child"), "copied bytes");
         GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp
           (Join (Source, "child"), GNAT.OS_Lib.GM_Time_Of (2020, 1, 2, 3, 4, 5));
         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Operations.Clear_Undo (Model);
         Files.Model.Set_Background_Transfers (Model, Background);
         Select_Name (Model, "original");
         Step := Complete_Operation (Model, Settings, Files.Operations.Duplicate_Selected (Model, Settings));
         Await_View (Model, Settings);
         Files_Suite.Support.Assert_Equal
           (Step.Status,
            Files.Operations.Operation_Success,
            "duplicate a directory containing a regular file");
         declare
            Child : constant String := Join (Dest, "child");
            Stamp : constant GNAT.OS_Lib.OS_Time := GNAT.OS_Lib.File_Time_Stamp (Child);
            Metadata : constant String := Files.File_Identities.Revision (Child, False);
            Snapshot : constant String := Files.File_System.Tree_Revision (Dest);
         begin
            Write_Binary_File (Child, "edited bytes");
            GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp (Child, Stamp);
            Assert (Files.File_Identities.Revision (Child, False) = Metadata
                    and then Files.File_System.Tree_Revision (Dest) /= Snapshot,
                    "a copied directory revision tracks same-size edits to a child");
            Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Await_View (Model, Settings);
            Files_Suite.Support.Assert_Equal
              (Step.Status,
               Files.Operations.Operation_Failed,
               "Undo retains a copied directory whose child bytes changed: status");
            Assert
              (Files.Model.Undo_Available (Model),
               "Undo retains a copied directory whose child bytes changed: undo kept");
            Assert
              (File_Has_Bytes (Child, "edited bytes"),
               "Undo retains a copied directory whose child bytes changed: edited bytes kept");
         end;
      end loop;
   exception
      when others => Files.Model.Clear_Paste_Execution (Model); Files.Refresh_Jobs.Cancel (Model); raise;
   end Test_Undo_Same_Size_Edits;
