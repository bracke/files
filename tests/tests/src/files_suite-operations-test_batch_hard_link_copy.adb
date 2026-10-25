separate (Files_Suite.Operations)
   procedure Test_Batch_Hard_Link_Copy (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Source : constant String := Join (Root, "source");
      Parent : constant String := Join (Root, "destination");
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Paths : Files.Types.String_Vectors.Vector;
      Step : Files.Operations.Operation_Result;
      First_Stamp : GNAT.OS_Lib.OS_Time;
      First_Revision : Unbounded_String;
      procedure Check is
      begin
         Assert (Files.File_Identities.Token (Join (Parent, "first")) /= ""
                 and then Files.File_Identities.Token (Join (Parent, "first")) =
                   Files.File_Identities.Token (Join (Parent, "second")),
                 "separately selected roots retain hard links");
         Assert (Files.File_Identities.Token (Join (Parent, "first")) /=
                   Files.File_Identities.Token (Join (Source, "first"))
                 and then Files.File_Identities.Token (Join (Parent, "first")) /=
                   Files.File_Identities.Token (Join (Parent, "third")),
                 "the copied family is independent of its source and unrelated identical files");
      end Check;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux then
         Files_Suite.Support.Skip ("Test_Batch_Hard_Link_Copy", "Hostkit.Host.Current /= Hostkit.Host.Linux");
         return;
      end if;
      for Background in Boolean loop
         Reset_Root;
         Ada.Directories.Create_Directory (Source);
         Ada.Directories.Create_Directory (Parent);
         Write_Binary_File (Join (Source, "first"), "shared bytes");
         GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp
           (Join (Source, "first"), GNAT.OS_Lib.Current_Time);
         Assert (Hostkit.Fs.Create_Hard_Link (Join (Source, "first"), Join (Source, "second")),
                 "prepare two selected roots sharing an inode");
         Write_Binary_File (Join (Source, "third"), "shared bytes");
         Paths.Clear;
         Paths.Append (To_Unbounded_String (Join (Source, "first")));
         Paths.Append (To_Unbounded_String (Join (Source, "second")));
         Paths.Append (To_Unbounded_String (Join (Source, "third")));
         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Model.Clear_Undo (Model);
         Files.Model.Set_Background_Transfers (Model, Background);
         Step := Complete_Operation (Model, Settings, Files.Operations.Begin_Paste_To (Model, Settings, Paths, Parent));
         Await_View (Model, Settings);
         Files_Suite.Support.Assert_Equal
           (Step.Status,
            Files.Operations.Operation_Success,
            "copy a hard-link family as separate roots");
         Check;
         Write_Binary_File (Join (Parent, "first"), "copied edit");
         Assert (File_Has_Bytes (Join (Parent, "second"), "copied edit"),
                 "editing a copied alias affects only its copied family: the copied alias sees it");
         Assert (File_Has_Bytes (Join (Source, "first"), "shared bytes"),
                 "editing a copied alias affects only its copied family: the source is untouched");
         Assert (File_Has_Bytes (Join (Parent, "third"), "shared bytes"),
                 "editing a copied alias affects only its copied family: the other copied family is untouched");
         Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
         Await_View (Model, Settings);
         Files_Suite.Support.Assert_Equal
           (Step.Status, Files.Operations.Operation_Failed, "Undo keeps an edited copied hard-link family: status");
         Assert (File_Has_Bytes (Join (Parent, "first"), "copied edit"),
                 "Undo keeps an edited copied hard-link family: the edit is kept");
         Assert (Files.Model.Undo_Available (Model), "Undo keeps an edited copied hard-link family: Undo retained");
         Write_Binary_File (Join (Parent, "first"), "shared bytes");
         GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp
           (Join (Parent, "first"), GNAT.OS_Lib.File_Time_Stamp (Join (Source, "first")));
         Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
         Await_View (Model, Settings);
         Files_Suite.Support.Assert_Equal
           (Step.Status,
            Files.Operations.Operation_Success,
            "restoring copied bytes permits the hard-link batch Undo");
         Step := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
         Await_View (Model, Settings);
         Files_Suite.Support.Assert_Equal
           (Step.Status,
            Files.Operations.Operation_Success,
            "Redo the copied hard-link batch");
         Check;
         Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
         Await_View (Model, Settings);
         Write_Binary_File (Join (Parent, "second"), "unrelated replacement");
         Step := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
         Await_View (Model, Settings);
         Assert (Step.Status = Files.Operations.Operation_Failed
                 and then File_Has_Bytes (Join (Parent, "second"), "unrelated replacement"),
                 "partial Redo retains completed copies and refuses unrelated replacements");
         Ada.Directories.Delete_File (Join (Parent, "second"));
         Step := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
         Await_View (Model, Settings);
         Files_Suite.Support.Assert_Equal
           (Step.Status,
            Files.Operations.Operation_Success,
            "retry a partially completed hard-link Redo");
         Check;
         Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
         Await_View (Model, Settings);
         Write_Binary_File (Join (Parent, "second"), "retry obstruction");
         Step := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
         Await_View (Model, Settings);
         Files_Suite.Support.Assert_Equal
           (Step.Status,
            Files.Operations.Operation_Failed,
            "prepare another partially completed hard-link Redo");
         First_Stamp := GNAT.OS_Lib.File_Time_Stamp (Join (Parent, "first"));
         First_Revision := To_Unbounded_String
           (Files.File_Identities.Revision (Join (Parent, "first"), False));
         Write_Binary_File (Join (Parent, "first"), "altered byte");
         GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp (Join (Parent, "first"), First_Stamp);
         Files_Suite.Support.Assert_Equal
           (Files.File_Identities.Revision (Join (Parent, "first"), False),
            To_String (First_Revision),
            "the regression edit preserves every field in the metadata-only revision");
         Ada.Directories.Delete_File (Join (Parent, "second"));
         Step := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
         Await_View (Model, Settings);
         Files_Suite.Support.Assert_Equal
           (Step.Status,
            Files.Operations.Operation_Failed,
            "a retry refuses a same-size edited copy even when its modification time is restored: status");
         Assert (File_Has_Bytes (Join (Parent, "first"), "altered byte"),
                 "a retry refuses a same-size edited copy even when its modification time is restored: edit kept");
         Assert (not Ada.Directories.Exists (Join (Parent, "second")),
                 "a retry refuses a same-size edited copy even when its modification time is restored: "
                 & "nothing recreated");
      end loop;
   exception
      when others =>
         Files.Model.Clear_Paste_Execution (Model);
         Files.Refresh_Jobs.Cancel (Model);
         raise;
   end Test_Batch_Hard_Link_Copy;
