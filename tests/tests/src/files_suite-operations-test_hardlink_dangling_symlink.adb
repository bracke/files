separate (Files_Suite.Operations)
   procedure Test_Hardlink_Dangling_Symlink
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Dir : constant String := Join (Root, "symlink-hardlink");
      Source : constant String := Join (Dir, "dangling");
      Direct_Link : constant String := Join (Dir, "direct");
      Link_Path : constant String := Join (Dir, "dangling (link)");
      Occupied : constant String := Join (Dir, "occupied");
      Mutation : Files.File_System.Mutation_Result;
      Load : Files.File_System.Directory_Load_Result;
      Model : Files.Model.Window_Model;
      Routed : Files.Controller.Controller_Result;
      Step : Files.Operations.Operation_Result;
      Target : Unbounded_String;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux then
         Files_Suite.Support.Skip ("Test_Hardlink_Dangling_Symlink", "needs Linux");
         return;
      end if;
      Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Assert (Hostkit.Fs.Create_Link ("missing-target", Source),
              "prepare a dangling symbolic link source");
      Mutation := Files.File_System.Create_Hard_Link (Source, Direct_Link);
      Assert (Mutation.Success, "direct creation hard-links the symbolic link entry itself: created");
      Assert (Hostkit.Fs.Is_Link (Direct_Link), "direct creation hard-links the symbolic link entry itself: a link");
      Files_Suite.Support.Assert_Equal
        (Files.File_Identities.Token (Direct_Link),
         Files.File_Identities.Token (Source),
         "direct creation hard-links the symbolic link entry itself: same inode");
      Assert (Hostkit.Fs.Read_Link_Target (Direct_Link, Target)
                and then To_String (Target) = "missing-target",
              "the direct hard link retains the unresolved target text");

      Assert (Hostkit.Fs.Create_Link ("missing-target", Occupied),
              "prepare a dangling destination collision");
      Mutation := Files.File_System.Create_Directory (Occupied);
      Assert (not Mutation.Success, "folder creation identifies and preserves a dangling link collision: refused");
      Files_Suite.Support.Assert_Equal
        (To_String (Mutation.Error_Key),
         "error.file.exists",
         "folder creation identifies and preserves a dangling link collision: error key");
      Assert (Hostkit.Fs.Is_Link (Occupied),
              "folder creation identifies and preserves a dangling link collision: link kept");
      Mutation := Files.File_System.Create_Symbolic_Link (Source, Occupied);
      Assert (not Mutation.Success and then To_String (Mutation.Error_Key) = "error.file.exists",
              "symbolic-link creation identifies a dangling link collision");
      Mutation := Files.File_System.Create_Hard_Link (Source, Occupied);
      Assert (not Mutation.Success and then To_String (Mutation.Error_Key) = "error.file.exists",
              "hard-link creation identifies a dangling link collision");

      Load := Files.File_System.Load_Directory (Dir, Settings);
      Files.Model.Initialize (Model, Dir, Load.Items, Root);
      Select_Name (Model, "dangling");
      Routed := Files.Controller.Execute_Command
        (Files.Commands.Create_Hardlink_Command, Model, Settings);
      Assert (Routed.Operation.Status = Files.Operations.Operation_Success
                and then Hostkit.Fs.Is_Link (Link_Path),
              "the selected dangling link can be hard-linked");
      Assert (Files.Model.Undo_Available (Model), "the created link has Undo history");
      Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Files_Suite.Support.Assert_Equal
        (Step.Status, Files.Operations.Operation_Success, "Undo removes only the new symbolic link entry: status");
      Assert (not Hostkit.Fs.Is_Link (Link_Path), "Undo removes only the new symbolic link entry: new link removed");
      Assert (Hostkit.Fs.Is_Link (Source), "Undo removes only the new symbolic link entry: source kept");
      Step := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
      Files_Suite.Support.Assert_Equal
        (Step.Status,
         Files.Operations.Operation_Success,
         "Redo recreates a hard link to the same symbolic link inode: status");
      Assert (Hostkit.Fs.Is_Link (Link_Path), "Redo recreates a hard link to the same symbolic link inode: a link");
      Files_Suite.Support.Assert_Equal
        (Files.File_Identities.Token (Link_Path),
         Files.File_Identities.Token (Source),
         "Redo recreates a hard link to the same symbolic link inode: same inode");
   end Test_Hardlink_Dangling_Symlink;
