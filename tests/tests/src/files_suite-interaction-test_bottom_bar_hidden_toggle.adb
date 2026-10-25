separate (Files_Suite.Interaction)
   --  Item 8/9: the bottom-bar status area reports the hidden (dot-file) count
   --  and doubles as a clickable Show_Hidden_Files toggle. Derive the click
   --  coordinate from the real bottom-bar accessibility node (rule a/b) and
   --  route it through the full Translate_Click -> Apply_Input_Action pipeline
   --  (rule d), asserting semantic outcomes only (rule c).
   procedure Test_Bottom_Bar_Hidden_Toggle (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Path : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "hidden-toggle.conf");

      function Items_With_Hidden return Files.File_System.Item_Vectors.Vector is
         Items : Files.File_System.Item_Vectors.Vector;
      begin
         Items.Append
           (Files.File_System.Make_Item
              (Files_Suite.Support.Root, "Alpha.txt", Files.Types.Regular_File_Item, "text/plain"));
         Items.Append
           (Files.File_System.Make_Item
              (Files_Suite.Support.Root, ".hidden_one", Files.Types.Regular_File_Item, "text/plain"));
         Items.Append
           (Files.File_System.Make_Item
              (Files_Suite.Support.Root, ".hidden_two", Files.Types.Regular_File_Item, "text/plain"));
         return Items;
      end Items_With_Hidden;

      Model    : Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Snapshot : Files.Rendering.View_Snapshot;
      Frame    : Files.Rendering.Frame_Commands;
      Action   : Files.Events.Input_Action;
      Toggle_Name : constant String :=
        Files.Localization.Text (Files.Commands.Name_Key (Files.Commands.Toggle_Hidden_Files_Command));
      X, Y     : Natural := 0;
      Found    : Boolean := False;
      Before   : Boolean;
   begin
      Files_Suite.Support.Reset_Root;
      Files.Model.Initialize
        (Model,
         Directory_Path    => Files_Suite.Support.Root,
         Items             => Items_With_Hidden,
         Home_Path         => "/home/test");

      --  The model query reports the two dot-files, and the snapshot carries it
      --  to the renderer.
      Files_Suite.Support.Assert_Equal
        (Files.Model.Hidden_Item_Count (Model),
         2,
         "the model counts both hidden dot-files");

      Snapshot := Files.Rendering.Build_Snapshot (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Snapshot.Hidden_Count,
         2,
         "the snapshot surfaces the hidden count for the bottom bar");

      Frame := Files.Rendering.Build_Frame_Commands (Snapshot, Window_W, Window_H, Line);

      --  Derive the click coordinate from the real bottom-bar control node.
      for Node of Frame.Accessibility loop
         if Node.Role = Guikit.Draw.Role_Button
           and then Ada.Strings.Unbounded.To_String (Node.Name) = Toggle_Name
         then
            X := Node.X + Node.Width / 2;
            Y := Node.Y + Node.Height / 2;
            Found := True;
         end if;
      end loop;
      Assert (Found, "the bottom-bar hidden-count control is exposed as an accessible button");

      Action :=
        Files.Events.Translate_Click
          (Snapshot, Frame, X, Y, Window_W, Window_H, Line_Height => Line);
      Assert
        (Action.Kind = Files.Events.Command_Input_Action
           and then Action.Command = Files.Commands.Toggle_Hidden_Files_Command,
         "the hidden-count region translates to the Toggle_Hidden_Files command");

      Before := Settings.Show_Hidden_Files;
      Files.Interaction.Apply_Input_Action
        (Model             => Model,
         Settings          => Settings,
         Settings_Path     => Path,
         Action            => Action,
         Current_Font_Size => Base_Font,
         Modifiers         => Guikit.Input.No_Modifiers,
         Result            => Result);

      Assert (Settings.Show_Hidden_Files /= Before, "clicking the hidden count flips Show_Hidden_Files");
      Assert (Result.Settings_Changed, "the hidden-count click reports a settings change");
      Assert (Result.Directory_Reloaded, "the hidden-count click reports the directory reload");
      Assert (Ada.Directories.Exists (Path), "the hidden-count click persists the settings file");
   end Test_Bottom_Bar_Hidden_Toggle;
