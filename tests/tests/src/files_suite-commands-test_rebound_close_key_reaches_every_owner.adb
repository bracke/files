with Files.Folder_Tree;
with Files.Model.Clipboard;
with Files.Model.Pasting;
with Files.Model.Tree_Panel;
with Files_Suite.Support.Disk;
with Files_Suite.Support.Guards;
with Files_Suite.Support.Models;
separate (Files_Suite.Commands)
   --  Rebound to a chord with a modifier (Ctrl+W), the close key reaches every
   --  owner Escape did: the folder tree hands its keyboard back and both paste
   --  dialogs cancel. Escape, no longer bound, does nothing there.
   procedure Test_Rebound_Close_Key_Reaches_Every_Owner (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  Clears the override this test sets, on an assertion failure too.
      Shortcuts : Files_Suite.Support.Guards.Shortcut_Guard;
      pragma Unreferenced (Shortcuts);
      Control  : constant Guikit.Input.Modifier_Set := [Guikit.Input.Control_Key => True, others => False];
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Root     : constant String := Files_Suite.Support.Disk.Root;
      Src_Dir  : constant String := Files_Suite.Support.Disk.Join (Root, "close-key-src");
      Dest_Dir : constant String := Files_Suite.Support.Disk.Join (Root, "close-key-dest");

      --  Key, with Modifiers, to Model as the window hands it over.
      procedure Press
        (Model     : in out Files.Model.Window_Model;
         Key       : Guikit.Input.Key_Code;
         Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers)
      is
         Unused : constant Files.Controller.Controller_Result :=
           Files.Controller.Testing.Handle_Key (Model, Settings, Key, Modifiers);
         pragma Unreferenced (Unused);
      begin
         null;
      end Press;
   begin
      Files.Commands.Reset_Shortcut_Overrides;
      Files.Commands.Set_Shortcut_Override
        (Files.Commands.Close_Overlay_Command, (Present => True, Key => Guikit.Input.Key_W, Modifiers => Control));

      --  The folder tree with the keyboard.
      declare
         Model : Files.Model.Window_Model := Files_Suite.Support.Models.Sample_Model;
         Seeds : Files.Folder_Tree.Entry_Seed_Vectors.Vector;
      begin
         Files_Suite.Support.Disk.Reset_Root;
         Seeds.Append
           (Files.Folder_Tree.Entry_Seed'(Path => To_Unbounded_String (Root), Name => To_Unbounded_String ("root")));
         Files.Model.Tree_Panel.Seed (Model, Seeds);
         Files.Model.Tree_Panel.Open (Model);
         Files.Model.Tree_Panel.Give_Keyboard (Model);
         Press (Model, Guikit.Input.Key_Escape);
         Assert (Files.Model.Tree_Panel.Has_Keyboard (Model), "Escape, unbound, leaves the tree its keyboard");
         Press (Model, Guikit.Input.Key_W, Control);
         Assert (not Files.Model.Tree_Panel.Has_Keyboard (Model), "Ctrl+W hands the keyboard back");
      end;

      --  The paste progress dialog.
      declare
         Model : aliased Files.Model.Window_Model;
         Paste : Files_Suite.Support.Guards.Paste_Guard (Model'Access);
         pragma Unreferenced (Paste);
      begin
         Files_Suite.Support.Models.Arm_Numbered_Paste (Model, Settings, Src_Dir, Dest_Dir, 3);
         Assert (Files.Model.Foreground_Job_Is_Active (Model), "a paste is running");
         Press (Model, Guikit.Input.Key_Escape);
         Assert (Files.Model.Foreground_Job_Is_Active (Model), "Escape, unbound, does not cancel it");
         Press (Model, Guikit.Input.Key_W, Control);
         Assert (not Files.Model.Foreground_Job_Is_Active (Model), "Ctrl+W cancels the paste");
      end;

      --  The paste conflict dialog.
      declare
         Model : Files.Model.Window_Model;
         Load  : Files.File_System.Directory_Load_Result;
         Paths : Files.Types.String_Vectors.Vector;
      begin
         Files_Suite.Support.Disk.Reset_Root;
         Ada.Directories.Create_Path (Src_Dir);
         Ada.Directories.Create_Path (Dest_Dir);
         Files_Suite.Support.Disk.Write_File (Files_Suite.Support.Disk.Join (Src_Dir, "a.txt"), "SRC");
         Files_Suite.Support.Disk.Write_File (Files_Suite.Support.Disk.Join (Dest_Dir, "a.txt"), "DEST");
         Load := Files.File_System.Load_Directory (Dest_Dir, Settings);
         Files.Model.Initialize (Model, Dest_Dir, Load.Items, Root);
         Paths.Append (To_Unbounded_String (Files_Suite.Support.Disk.Join (Src_Dir, "a.txt")));
         Files.Model.Clipboard.Set (Model, Paths, Files.Model.Clipboard_Copy);
         declare
            Unused : constant Files.Controller.Controller_Result :=
              Files.Controller.Execute_Non_Settings_Command (Files.Commands.Paste_Items_Command, Model, Settings);
            pragma Unreferenced (Unused);
         begin
            null;
         end;
         Assert (Files.Model.Pasting.Conflict_Is_Active (Model), "a colliding paste asks");
         Press (Model, Guikit.Input.Key_Escape);
         Assert (Files.Model.Pasting.Conflict_Is_Active (Model), "Escape, unbound, leaves the question open");
         Press (Model, Guikit.Input.Key_W, Control);
         Assert (not Files.Model.Pasting.Conflict_Is_Active (Model), "Ctrl+W cancels the paste");
         Assert
           (Ada.Directories.Exists (Files_Suite.Support.Disk.Join (Dest_Dir, "a.txt")),
            "the destination is left where it was");
      end;
      Files.Commands.Reset_Shortcut_Overrides;
   end Test_Rebound_Close_Key_Reaches_Every_Owner;
