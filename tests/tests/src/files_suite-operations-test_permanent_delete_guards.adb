with Files.Commands.Status;
separate (Files_Suite.Operations)
   procedure Test_Permanent_Delete_Guards (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Mutation : Files.File_System.Mutation_Result;
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Routed   : Files.Controller.Controller_Result;
      Delete_Dir  : constant String := Join (Root, "delete-tree");
      Cache_Home : constant String := Join (Root, "cache-home");
      Environment : Files_Suite.Support.Environment_Guard;
   begin
      Reset_Root;
      Files_Suite.Support.Save (Environment, "XDG_CACHE_HOME");
      Ada.Directories.Create_Path (Delete_Dir);
      Write_File (Join (Delete_Dir, "doomed.txt"), "doomed");
      Ada.Directories.Create_Path (Join (Delete_Dir, "nested"));
      Write_File (Join (Join (Delete_Dir, "nested"), "child.txt"), "child");
      Mutation := Files.File_System.Delete_Permanently (Delete_Dir);
      Assert (Mutation.Success, "explicit permanent delete removes a tree");
      Assert (not Ada.Directories.Exists (Delete_Dir), "permanent delete removes the target directory");
      Mutation := Files.File_System.Delete_Permanently ("/");
      Assert (not Mutation.Success, "permanent delete refuses root paths");
      Files_Suite.Support.Assert_Equal
        (To_String (Mutation.Error_Key),
         "error.permanent_delete.refused",
         "permanent delete reports unsafe target diagnostic");

      --  A child/.. spelling names the parent directory. Recursive deletion
      --  through that spelling could erase its contents before rmdir fails.
      declare
         Guard : constant String := Join (Root, "dot-delete-guard");
         Child : constant String := Join (Guard, "child");
         Kept : constant String := Join (Guard, "keep.txt");
         procedure Check_Refusal (Attempt : String) is
         begin
            Mutation := Files.File_System.Delete_Permanently (Attempt);
            Assert (not Mutation.Success
                      and then To_String (Mutation.Error_Key) = "error.permanent_delete.refused",
                    "permanent delete refuses dot and parent path components");
            Assert (Ada.Directories.Exists (Child) and then Ada.Directories.Exists (Kept),
                    "a refused navigation path leaves the parent tree intact");
         end Check_Refusal;
      begin
         Ada.Directories.Create_Path (Child);
         Write_File (Kept, "keep this file");
         Check_Refusal (Child & "/..");
         Check_Refusal (Guard & "/.");
         Check_Refusal (Guard & "/./keep.txt");
         Check_Refusal (Child & "/../keep.txt");
      end;

      if Hostkit.Host.Current /= Hostkit.Host.Windows then
         declare
            Literal_Dotdot : constant String := Join (Root, "literal\..");
         begin
            Write_File (Literal_Dotdot, "ordinary POSIX name");
            Mutation := Files.File_System.Delete_Permanently (Literal_Dotdot);
            Assert
              (Mutation.Success and then not Ada.Directories.Exists (Literal_Dotdot),
               "permanent delete does not treat a POSIX backslash as navigation");
         end;
      end if;

      --  Regression: permanent-delete of a symlink to a directory must unlink
      --  the LINK, never follow it and recursively wipe the target's real
      --  contents (the previous Directory_Exists + Delete_Tree path did).
      declare
         Link_Target   : constant String := Join (Root, "sym-del-target");
         Kept_File     : constant String := Join (Link_Target, "precious.txt");
         Dir_Link      : constant String := Join (Root, "sym-del-link");
         Link_Result   : Files.File_System.Mutation_Result;
         Target_Kept   : Boolean := False;
         Content_Kept  : Boolean := False;
         Link_Gone     : Boolean := False;
      begin
         Ada.Directories.Create_Path (Link_Target);
         Write_File (Kept_File, "precious");
         if Files_Suite.Support.Create_Symlink (Link_Target, Dir_Link) then
            Link_Result := Files.File_System.Delete_Permanently (Dir_Link);
            --  Capture before cleanup so a failure cannot leave fixtures behind.
            Target_Kept  := Ada.Directories.Exists (Link_Target);
            Content_Kept := Ada.Directories.Exists (Kept_File);
            Link_Gone    := not Hostkit.Fs.Is_Link (Dir_Link);
            if Hostkit.Fs.Is_Link (Dir_Link) then
               declare
                  Removed : constant Boolean := Hostkit.Fs.Delete_Link (Dir_Link);
                  pragma Unreferenced (Removed);
               begin
                  null;
               end;
            end if;
            if Ada.Directories.Exists (Link_Target) then
               Project_Tools.Files.Delete_Tree (Link_Target);
            end if;
            Assert (Link_Result.Success, "permanent delete of a directory symlink succeeds");
            Assert (Link_Gone, "permanent delete removes the symlink itself");
            Assert (Target_Kept, "permanent delete of a symlink does not delete the link target directory");
            Assert (Content_Kept, "permanent delete of a symlink preserves the target's real contents");
         else
            Files_Suite.Support.Link_Not_Made ("Test_Permanent_Delete_Guards", Files_Suite.Support.Symbolic_Link);
         end if;
      end;

      --  Directory listings read the thumbnail cache, so keep it inside the fixture.
      Ada.Environment_Variables.Set ("XDG_CACHE_HOME", Cache_Home);
      Write_File (Join (Root, "command-delete.txt"), "delete");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "command-delete.txt");
      Assert
        (Files.Commands.Status.Is_Enabled (Files.Commands.Delete_Selected_Permanently_Command, Model),
         "permanent delete command is enabled for selected items");
      Routed :=
        Files.Controller.Execute_Command
          (Files.Commands.Delete_Selected_Permanently_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Routed.Command,
         Files.Commands.Delete_Selected_Permanently_Command,
         "permanent delete routes through command registry");
      Files_Suite.Support.Assert_Equal
        (Routed.Operation.Status,
         Files.Operations.Operation_Success,
         "permanent delete command succeeds");
      Assert
        (not Ada.Directories.Exists (Join (Root, "command-delete.txt")),
         "permanent delete command removes the selected file");
   end Test_Permanent_Delete_Guards;
