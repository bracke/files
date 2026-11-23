with Files.Overlays.Settings_Form;
with Files.Settings.Drafts;
separate (Files_Suite.Settings)
   --  Another window's or process's rebind taken in while the settings pane
   --  is open merges with the pane's draft per command, as its scalars
   --  merge per setting: the command rebound there takes that binding, and
   --  a shortcut edited in the pane and not yet saved stays.
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
   end Test_Outside_Rebind_Keeps_Draft_Shortcuts;
