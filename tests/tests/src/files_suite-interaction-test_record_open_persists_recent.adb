separate (Files_Suite.Interaction)
   procedure Test_Record_Open_Persists_Recent (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Ada.Strings.Unbounded;
      Dir      : constant String :=
        Files_Suite.Support.Join (Files_Suite.Support.Root, "opened-dir");
      Path     : constant String :=
        Files_Suite.Support.Join (Files_Suite.Support.Root, "recent.conf");
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Items    : Files.File_System.Item_Vectors.Vector;
      Model    : Files.Model.Window_Model;
      Result   : Files.Interaction.Interaction_Result;
      Action   : constant Files.Events.Input_Action :=
        (Kind    => Files.Events.Command_Input_Action,
         Command => Files.Commands.Open_Selected_Items_Command,
         others  => <>);
   begin
      Files_Suite.Support.Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Items.Append
        (Files.File_System.Make_Item
           (Files_Suite.Support.Root, "opened-dir", Files.Types.Directory_Item, "inode/directory"));
      Files.Model.Initialize (Model, Files_Suite.Support.Root, Items, Files_Suite.Support.Root);
      Files.Model.Select_Visible (Model, 1);

      Files.Interaction.Apply_Input_Action
        (Model             => Model,
         Settings          => Settings,
         Settings_Path     => Path,
         Action            => Action,
         Current_Font_Size => Base_Font,
         Modifiers         => Guikit.Input.No_Modifiers,
         Result            => Result);

      declare
         Recent : constant Files.Types.String_Vectors.Vector :=
           Files.Settings.Recent_Paths (Settings);
      begin
         Assert (not Recent.Is_Empty, "opening an item records it in the recent list");
         Files_Suite.Support.Assert_Equal
           (To_String (Recent.First_Element),
            Ada.Directories.Full_Name (Dir),
            "the opened folder lands at the front of the recent list");
      end;
      Assert (Result.Settings_Changed, "recording an open reports a settings change");
      Assert (Ada.Directories.Exists (Path), "recording an open persists the settings file");
   end Test_Record_Open_Persists_Recent;
