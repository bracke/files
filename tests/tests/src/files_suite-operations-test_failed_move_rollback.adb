separate (Files_Suite.Operations)
   procedure Test_Failed_Move_Rollback (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Mutation : Files.File_System.Mutation_Result;
      Sources : Files.Types.String_Vectors.Vector;
      Source_Parent : constant String := Join (Root, "source");
      Destination : constant String := Join (Root, "destination");
      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Environment_Guard;
      procedure Restore is
      begin
         if Ada.Directories.Exists (Source_Parent) then
            Mutation := Files.File_System.Set_Permissions (Source_Parent, 8#755#);
         end if;
      end Restore;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux then
         Files_Suite.Support.Skip ("Test_Failed_Move_Rollback", "needs Linux");
         return;
      end if;
      Files_Suite.Support.Save (Environment, "XDG_DATA_HOME");
      for Background in Boolean loop
         for Replace in Boolean loop
            Reset_Root;
            Ada.Directories.Create_Directory (Source_Parent);
            Ada.Directories.Create_Directory (Destination);
            Ada.Environment_Variables.Set ("XDG_DATA_HOME", Join (Root, "xdg"));
            Write_Binary_File (Join (Source_Parent, "item.txt"), "source bytes");
            if Replace then
               Write_Binary_File (Join (Destination, "item.txt"), "original bytes");
            end if;
            Load := Files.File_System.Load_Directory (Destination, Settings);
            Files.Model.Initialize (Model, Destination, Load.Items, Root);
            Files.Operations.Clear_Undo (Model);
            Files.Model.Set_Background_Transfers (Model, Background);
            Sources.Clear;
            Sources.Append (To_Unbounded_String (Join (Source_Parent, "item.txt")));
            Mutation := Files.File_System.Set_Permissions (Source_Parent, 8#555#);
            Assert (Mutation.Success, "deny source unlink and rename");
            Step := Files.Operations.Begin_Paste
              (Model, Settings, Sources, Files.File_System.Drop_Move, False);
            if Replace then
               Step := Files.Operations.Resolve_Paste_Conflict
                 (Model, Settings, Files.Operations.Choice_Replace, True);
            end if;
            Step := Complete_Operation (Model, Settings, Step);
            Await_View (Model, Settings);
            Mutation := Files.File_System.Set_Permissions (Source_Parent, 8#755#);
            Files_Suite.Support.Assert_Equal
              (Step.Status,
               Files.Operations.Operation_Failed,
               "a refused move leaves its source intact and no unusable Undo entry: the move fails");
            Assert (File_Has_Bytes (Join (Source_Parent, "item.txt"), "source bytes"),
                    "a refused move leaves its source intact and no unusable Undo entry: source intact");
            Assert (not Files.Model.Undo_Available (Model),
                    "a refused move leaves its source intact and no unusable Undo entry: no Undo entry");
            Assert ((if Replace then File_Has_Bytes (Join (Destination, "item.txt"), "original bytes")
                     else not Ada.Directories.Exists (Join (Destination, "item.txt"))),
                    "the published copy is removed and a replaced destination is restored");
         end loop;
      end loop;
      Restore;
   exception
      when others =>
         Restore;
         Files.Model.Clear_Paste_Execution (Model);
         Files.Refresh_Jobs.Cancel (Model);
         raise;
   end Test_Failed_Move_Rollback;
