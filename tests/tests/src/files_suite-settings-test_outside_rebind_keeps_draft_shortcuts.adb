with Files.Overlays.Settings_Form;
with Files.Settings.Drafts;
with Files.Commands.Testing;
with Files.Settings.Storage.Testing;
with Files.Interaction;
with Files.Interaction.Testing;
with Files_Suite.Support.Guards;
separate (Files_Suite.Settings)
   --  Another window's or process's rebind taken in while the settings pane
   --  is open merges with the pane's draft per command, as its scalars
   --  merge per setting: the command rebound there takes that binding, and
   --  a shortcut edited in the pane and not yet saved stays. Taken in from
   --  the file another process wrote, the rebind is in the draft, so the
   --  pane's next save -- of something else -- keeps it in the file rather
   --  than writing the draft's old list over it.
   procedure Test_Outside_Rebind_Keeps_Draft_Shortcuts (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Settings.Shortcut_Override_Vectors.Vector;
      Model    : Files.Model.Window_Model := Files_Suite.Support.Models.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Shared   : Files.Settings.Settings_Model;
      Draft    : Files.Settings.Settings_Draft;

      function Override (Command, Combo : String) return Files.Settings.Shortcut_Override is
        (Command => To_Unbounded_String (Command), Combo => To_Unbounded_String (Combo));

      --  The combos Overrides holds for Command, joined.
      function Combos
        (Overrides : Files.Settings.Shortcut_Override_Vectors.Vector;
         Command   : String)
         return String
      is
         Text : Unbounded_String;
      begin
         for Entry_Of of Overrides loop
            if To_String (Entry_Of.Command) = Command then
               Append (Text, To_String (Entry_Of.Combo) & ";");
            end if;
         end loop;
         return To_String (Text);
      end Combos;
   begin
      Settings.Shortcut_Overrides.Append (Override ("view.small", "control+shift+1"));

      --  The pure merge first.
      Draft := Files.Settings.Drafts.Make_Draft (Settings);
      Draft.Shortcut_Overrides.Append (Override ("view.large", "control+shift+9"));
      Shared := Settings;
      Shared.Shortcut_Overrides.Clear;
      Shared.Shortcut_Overrides.Append (Override ("view.small", "control+shift+2"));
      Shared.Shortcut_Overrides.Append (Override ("view.details", "control+shift+3"));
      Draft := Files.Settings.Drafts.Refresh_Draft (Draft, Settings, Shared);
      Assert_Equal (Combos (Draft.Shortcut_Overrides, "view.small"), "control+shift+2;",
                    "the command rebound there takes it");
      Assert_Equal (Combos (Draft.Shortcut_Overrides, "view.details"), "control+shift+3;",
                    "a command bound there is added");
      Assert_Equal (Combos (Draft.Shortcut_Overrides, "view.large"), "control+shift+9;",
                    "the pane's own edit stays");
      Draft := Files.Settings.Drafts.Refresh_Draft (Draft, Shared, Shared);
      Assert_Equal (Combos (Draft.Shortcut_Overrides, "view.large"), "control+shift+9;",
                    "an unchanged take-in keeps it too");

      --  And through the window: the pane open with an unsaved capture.
      Files.Overlays.Settings_Form.Begin_Edit (Model, Settings);
      Draft := Files.Model.Settings_Pane.Draft_Of (Model);
      Draft.Shortcut_Overrides.Append (Override ("view.large", "control+shift+9"));
      Files.Overlays.Settings_Form.Set_Draft (Model, Draft);
      Files.Controller.Adopt_Shared_Settings (Model, Settings, Shared);
      Draft := Files.Model.Settings_Pane.Draft_Of (Model);
      Assert_Equal (Combos (Draft.Shortcut_Overrides, "view.small"), "control+shift+2;",
                    "the pane shows the outside rebind");
      Assert_Equal (Combos (Draft.Shortcut_Overrides, "view.large"), "control+shift+9;",
                    "and keeps the shortcut captured in it, not yet saved");
      Assert (Settings.Shortcut_Overrides = Shared.Shortcut_Overrides, "the window's settings are the shared ones");

      --  And from the file another process wrote, taken in by this window's
      --  next save while the pane is open.
      declare
         Path      : constant String := Join (Root, "rebind.conf");
         Small     : constant String := Files.Commands.Identifier (Files.Commands.Select_Small_Icons_Command);
         Shortcuts : Files_Suite.Support.Guards.Shortcut_Guard;
         pragma Unreferenced (Shortcuts);
         Window    : Files.Model.Window_Model := Files_Suite.Support.Models.Sample_Model;
         Mine      : Files.Settings.Settings_Model;
         Theirs    : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Written   : Files.Settings.Settings_Write_Result;
         Loaded    : Files.Settings.Settings_Parse_Result;
         Result    : Files.Interaction.Interaction_Result;
         use type Files.Commands.Shortcut;
      begin
         Reset_Root;
         Files.Commands.Testing.Reset_Shortcut_Overrides;
         Written := Files.Settings.Storage.Testing.Save_Text
           (Path, Files.Settings.To_Text (Files.Settings.Default_Settings));
         Assert (Written.Success, "the shared file is written");
         Loaded := Files.Settings.Storage.Load_File (Path);
         Assert (Loaded.Success, "and this window loads it");
         Mine := Loaded.Settings;
         Files.Overlays.Settings_Form.Begin_Edit (Window, Mine);

         --  Written as the settings write a chord, so every copy reads alike.
         Theirs.Shortcut_Overrides.Append (Override (Small, "shift+control+7"));
         Write_File (Path, Files.Settings.To_Text (Theirs));
         Mine.Show_Hidden_Files := True;
         Files.Controller.Persist_Settings (Window, Mine, Path);
         Assert_Equal (Combos (Mine.Shortcut_Overrides, Small), "shift+control+7;",
                       "this window's save takes the other's rebind in");
         Assert_Equal (Combos (Files.Model.Settings_Pane.Draft_Of (Window).Shortcut_Overrides, Small),
                       "shift+control+7;", "the open pane's draft holds it");

         --  A save from the pane of something else.
         Draft := Files.Model.Settings_Pane.Draft_Of (Window);
         Draft.Scalars (Files.Settings.Show_File_Extensions_Setting) :=
           To_Unbounded_String
             (if Files.Settings.Testing.Scalar_Text (Mine, Files.Settings.Show_File_Extensions_Setting) = "true"
              then "false" else "true");
         Files.Overlays.Settings_Form.Set_Draft (Window, Draft);
         Files.Interaction.Testing.Execute_Command
           (Window, Mine, Path, Files.Commands.Save_Settings_Command, Result => Result);
         Loaded := Files.Settings.Storage.Load_File (Path);
         Assert (Loaded.Success, "the pane's save is written");
         Assert_Equal (Combos (Loaded.Settings.Shortcut_Overrides, Small), "shift+control+7;",
                       "and keeps the other's rebind in the file");
         Assert (Files.Commands.Shortcut_For (Files.Commands.Select_Small_Icons_Command)
                 = Files.Commands.Parse_Shortcut ("shift+control+7"),
                 "which is in force here");
         Reset_Root;
      end;
   end Test_Outside_Rebind_Keeps_Draft_Shortcuts;
