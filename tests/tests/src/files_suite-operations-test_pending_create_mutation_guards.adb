separate (Files_Suite.Operations)
   procedure Test_Pending_Create_Mutation_Guards
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      type Mutation_Kind is
        (Duplicate_Item, Compress_Item, Extract_Item,
         Create_Symbolic_Link, Create_Hard_Link);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Routed : Files.Controller.Controller_Result;
   begin
      for Background in Boolean loop
         for Kind in Mutation_Kind loop
            Reset_Root;
            Write_Binary_File (Join (Root, "source.zip"), "not an archive");
            Load := Files.File_System.Load_Directory (Root, Settings);
            Files.Model.Initialize (Model, Root, Load.Items, Root);
            Files.Operations.Clear_Undo (Model);
            Files.Model.Set_Background_Transfers (Model, Background);
            Files.Model.Begin_Create_File (Model, "pending.txt");
            Files.Model.Toggle_Visible_Selection (Model, 1);
            Assert
              (Files.Model.Selection_Includes_Temporary (Model)
               and then Files.Model.Selected_Count (Model) = 2,
               "prepare a real-plus-temporary mixed selection");

            Step :=
              (case Kind is
                  when Duplicate_Item =>
                    Files.Operations.Duplicate_Selected (Model, Settings),
                  when Compress_Item =>
                    Files.Operations.Compress_Selected
                      (Model, Settings, Files.Operations.Zip_Archive),
                  when Extract_Item =>
                    Files.Operations.Extract_Selected (Model, Settings),
                  when Create_Symbolic_Link =>
                    Files.Operations.Create_Symlink_Selected (Model, Settings),
                  when Create_Hard_Link =>
                    Files.Operations.Create_Hardlink_Selected (Model, Settings));
            declare
               Context : constant String := "direct selection mutations preserve a pending inline creation";
            begin
               Files_Suite.Support.Assert_Equal
                 (Step.Status, Files.Operations.Operation_Disabled, Context & ": status");
               Files_Suite.Support.Assert_Equal
                 (Files.Model.Last_Error_Key (Model), "error.create.pending", Context & ": error key");
               Assert (Files.Model.Temporary_Item_Is_Active (Model), Context & ": the inline creation stays active");
               Assert (not Files.Model.Undo_Available (Model), Context & ": no Undo entry");
               Assert (not Files.Process_Jobs.Active (Files.Model.Background_Operation (Model)),
                       Context & ": no background operation");
               Assert (not Ada.Directories.Exists (Join (Root, "source (copy).zip")), Context & ": no duplicate");
               Assert (not Ada.Directories.Exists (Join (Root, "source (1).zip")), Context & ": no archive");
               Assert (not Ada.Directories.Exists (Join (Root, "source")), Context & ": no extraction");
               Assert (not Ada.Directories.Exists (Join (Root, "source (link).zip")), Context & ": no link entry");
               Assert (not Hostkit.Fs.Is_Link (Join (Root, "source (link).zip")), Context & ": no dangling link");
            end;

            if Kind = Duplicate_Item then
               Routed := Files.Controller.Execute_Command
                 (Files.Commands.Duplicate_Selected_Command, Model, Settings);
               Files_Suite.Support.Assert_Equal
                 (Routed.Status,
                  Files.Controller.Controller_Ignored,
                  "the disabled command reports the pending edit instead of failing silently: controller status");
               Files_Suite.Support.Assert_Equal
                 (Routed.Operation.Status,
                  Files.Operations.Operation_Disabled,
                  "the disabled command reports the pending edit instead of failing silently: operation status");
               Files_Suite.Support.Assert_Equal
                 (To_String (Routed.Operation.Error_Key),
                  "error.create.pending",
                  "the disabled command reports the pending edit instead of failing silently: error key");
            end if;
         end loop;
      end loop;

      --  Clipboard paste, native file drops, and item-targeted drops all share
      --  Begin_Paste_To. None may write underneath the active inline editor.
      Reset_Root;
      Ada.Directories.Create_Directory (Join (Root, "inbox"));
      Ada.Directories.Create_Directory (Join (Root, "view"));
      Write_Binary_File (Join (Join (Root, "inbox"), "incoming.txt"), "incoming");
      Load := Files.File_System.Load_Directory (Join (Root, "view"), Settings);
      Files.Model.Initialize (Model, Join (Root, "view"), Load.Items, Root);
      Files.Model.Begin_Create_File (Model, "pending.txt");
      declare
         Sources : Files.Types.String_Vectors.Vector;
         Outcome : Files.Controller.Controller_Result;
      begin
         Sources.Append
           (To_Unbounded_String (Join (Join (Root, "inbox"), "incoming.txt")));
         Step := Files.Operations.Begin_Paste (Model, Settings, Sources);
         declare
            Context : constant String := "clipboard paste cannot write beneath a pending inline creation";
         begin
            Files_Suite.Support.Assert_Equal (Step.Status, Files.Operations.Operation_Disabled, Context & ": status");
            Files_Suite.Support.Assert_Equal
              (To_String (Step.Error_Key), "error.create.pending", Context & ": error key");
            Assert (Files.Model.Temporary_Item_Is_Active (Model), Context & ": the inline creation stays active");
            Assert (not Files.Model.Paste_Execution_Is_Active (Model), Context & ": no paste execution");
            Assert (not Files.Model.Paste_Conflict_Is_Active (Model), Context & ": no paste conflict");
            Assert (not Ada.Directories.Exists (Join (Join (Root, "view"), "incoming.txt")),
                    Context & ": nothing written");
         end;
         Outcome := Files.Controller.Handle_Drop_Import
           (Model, Settings, Sources);
         Files_Suite.Support.Assert_Equal
           (Outcome.Operation.Status,
            Files.Operations.Operation_Disabled,
            "external drops share the pending-create paste guard: status");
         Files_Suite.Support.Assert_Equal
           (To_String (Outcome.Operation.Error_Key),
            "error.create.pending",
            "external drops share the pending-create paste guard: error key");
         Assert
           (Files.Model.Temporary_Item_Is_Active (Model),
            "external drops share the pending-create paste guard: the inline creation stays active");
         Assert
           (not Ada.Directories.Exists (Join (Join (Root, "view"), "incoming.txt")),
            "external drops share the pending-create paste guard: nothing written");
         Step := Files.Operations.Begin_Paste_To
           (Model, Settings, Sources, Join (Root, "view"),
            Files.File_System.Drop_Move, From_Clipboard => False);
         Files_Suite.Support.Assert_Equal
           (Step.Status,
            Files.Operations.Operation_Disabled,
            "targeted moves preserve both the pending editor and their source: status");
         Assert
           (Ada.Directories.Exists (Join (Join (Root, "inbox"), "incoming.txt")),
            "targeted moves preserve both the pending editor and their source: source kept");
         Assert
           (not Ada.Directories.Exists (Join (Join (Root, "view"), "incoming.txt")),
            "targeted moves preserve both the pending editor and their source: nothing written");
      end;
   exception
      when others =>
         Files.Model.Clear_Paste_Execution (Model);
         Files.Refresh_Jobs.Cancel (Model);
         raise;
   end Test_Pending_Create_Mutation_Guards;
