with Files.Commands.Testing;
with Files.Settings.Drafts;
with Files.Commands.Keymap_Settings;
with Files.Overlays.Settings_Form;
with Files.Model.Settings_Pane;
with Files_Suite.Support.Guards;
separate (Files_Suite.Settings)
   --  Files.Overlays.Settings_Form maps a draft to typed panel fields and applies the
   --  panel's emitted changes: paging (Prev/Next) moves the selected mapping
   --  entry without saving, Add/Remove edit the list and save, and the key
   --  field's label carries the "i/n" entry counter.
   --  The Shortcuts tab: the form emits one press-to-capture row per command
   --  carrying its binding, and Apply routes a captured chord to the keymap the
   --  draft holds -- rebinding, rejecting a clash with another command,
   --  unbinding on an empty chord, and clearing the override when set to
   --  default. The live keymap waits for an accepted save.
   procedure Test_Shortcut_Editing (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  Clears the overrides this test sets, on an assertion failure too.
      Shortcuts : Files_Suite.Support.Guards.Shortcut_Guard;
      pragma Unreferenced (Shortcuts);
      package SP renames Guikit.Settings_Panel;
      use type SP.Field_Kind;

      Base  : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Draft : constant Files.Settings.Settings_Draft := Files.Settings.Drafts.Make_Draft (Base);
      Model : Files.Model.Window_Model;
      Saved : Boolean;

      --  The capture flow always feeds Apply the canonical Shortcut_Text form
      --  (modifiers normalised to shift+control+alt+meta), so the test uses it too.
      New_Chord : constant String :=
        Files.Commands.Shortcut_Text (Files.Commands.Parse_Shortcut ("control+shift+5"));

      function Change (Key, Value : String) return SP.Change is
        ((Kind => SP.Value_Changed, Key => To_Unbounded_String (Key), Value => To_Unbounded_String (Value)));

      function Row_Value (Key : String) return String is
         Fields : constant SP.Field_Vectors.Vector :=
           Files.Overlays.Settings_Form.Fields (Files.Model.Settings_Pane.Draft_Of (Model));
      begin
         for F of Fields loop
            if To_String (F.Key) = Key then
               return (if F.Kind = SP.Shortcut then To_String (F.Value) else "<not-a-shortcut>");
            end if;
         end loop;
         return "<absent>";
      end Row_Value;

      --  The keymap the pane's draft holds.
      function Draft_Map return Files.Commands.Keymap is
        (Files.Commands.Keymap_Settings.Keymap_Of (Files.Model.Settings_Pane.Draft_Of (Model).Shortcut_Overrides));

      --  Whether the draft overrides Identifier at all.
      function Draft_Overrides (Identifier : String) return Boolean is
      begin
         for Item of Files.Model.Settings_Pane.Draft_Of (Model).Shortcut_Overrides loop
            if To_String (Item.Command) = Identifier then
               return True;
            end if;
         end loop;
         return False;
      end Draft_Overrides;

      Small_Text : constant String :=
        Files.Commands.Shortcut_Text
          (Files.Commands.Default_Shortcut_For (Files.Commands.Select_Small_Icons_Command));
   begin
      Files.Commands.Testing.Reset_Shortcut_Overrides;
      Files.Overlays.Settings_Form.Begin_Edit (Model, Base);
      Files.Overlays.Settings_Form.Set_Draft (Model, Draft);

      --  The form emits a row per command, keyed by "shortcut.<identifier>",
      --  showing the command's current shortcut.
      Files_Suite.Support.Assert_Equal
        (Row_Value ("shortcut.view.small"),
         Small_Text,
         "the shortcut row shows the command's current binding");

      --  Rebind Small Icons to a fresh chord (a key added by the expansion).
      Saved := Files.Overlays.Settings_Form.Apply_Change (Model, Change ("shortcut.view.small", New_Chord));
      Assert (Saved, "rebinding a shortcut saves");
      declare
         SC : constant Files.Commands.Shortcut :=
           Files.Commands.Shortcut_For (Draft_Map, Files.Commands.Select_Small_Icons_Command);
         Is_Set : Boolean;
         Ignore : constant Files.Commands.Shortcut :=
           Files.Commands.Testing.Shortcut_Override (Files.Commands.Select_Small_Icons_Command, Is_Set);
      begin
         pragma Unreferenced (Ignore);
         Assert (SC.Present, "the draft's keymap holds the rebind (present)");
         Files_Suite.Support.Assert_Equal (SC.Key, Guikit.Input.Key_5, "the draft's keymap holds the rebind (key)");
         Assert (SC.Modifiers (Guikit.Input.Control_Key), "the draft's keymap holds the rebind (Control)");
         Assert (SC.Modifiers (Guikit.Input.Shift_Key), "the draft's keymap holds the rebind (Shift)");
         Assert (Draft_Overrides ("view.small"), "the rebind is recorded as an override in the draft");
         Assert (not Is_Set, "the live keymap waits for a save of the draft");
         Files_Suite.Support.Assert_Equal
           (Row_Value ("shortcut.view.small"),
            New_Chord,
            "the row now shows the new chord");
      end;

      --  Binding the same chord to a different command is rejected as a conflict.
      Saved := Files.Overlays.Settings_Form.Apply_Change (Model, Change ("shortcut.view.large", New_Chord));
      Assert (not Saved, "a conflicting rebind does not save");
      Assert (Files.Commands.Find_By_Shortcut
                (Draft_Map,
                 Guikit.Input.Key_5,
                 [Guikit.Input.Control_Key => True, Guikit.Input.Shift_Key => True, others => False])
              = Files.Commands.Select_Small_Icons_Command,
              "the chord still resolves to its original command after a rejected clash");

      --  An empty chord unbinds the command.
      Saved := Files.Overlays.Settings_Form.Apply_Change (Model, Change ("shortcut.view.small", ""));
      Assert (Saved, "unbinding saves");
      Assert (not Files.Commands.Shortcut_For (Draft_Map, Files.Commands.Select_Small_Icons_Command).Present,
              "the command has no shortcut after an empty-chord unbind");

      --  Setting a command back to its built-in default clears the override.
      Saved := Files.Overlays.Settings_Form.Apply_Change (Model, Change ("shortcut.view.small", Small_Text));
      Assert (Saved, "restoring the default saves");
      Assert (not Draft_Overrides ("view.small"), "binding a command to its default clears the override");

      --  The pane's Reset button is a full reset: it clears shortcut overrides
      --  too, not just the draft values -- here one that is saved, so that
      --  dropping it changes what is saved.
      declare
         With_Override : Files.Settings.Settings_Model := Base;
      begin
         With_Override.Shortcut_Overrides.Append
           (Files.Settings.Shortcut_Override'
              (Command => To_Unbounded_String ("view.small"), Combo => To_Unbounded_String (New_Chord)));
         Files.Overlays.Settings_Form.Begin_Edit (Model, With_Override);
      end;
      Assert (Draft_Overrides ("view.small"), "the pane opens on the saved override");
      Saved := Files.Overlays.Settings_Form.Apply_Change
        (Model,
         (Kind  => SP.Button_Pressed,
          Key   => To_Unbounded_String ("form.actions"),
          Value => To_Unbounded_String ("reset")));
      Assert (Saved, "the reset button saves");
      Assert (Files.Model.Settings_Pane.Draft_Of (Model).Shortcut_Overrides.Is_Empty,
              "Reset clears shortcut overrides, returning the draft's keymap to defaults");

      --  A command with a built-in secondary shortcut surfaces it (read-only) in
      --  its row help, so an "already used" rejection is explicable.
      declare
         Fields   : constant SP.Field_Vectors.Vector :=
           Files.Overlays.Settings_Form.Fields (Files.Model.Settings_Pane.Draft_Of (Model));
         Sec_Cmd  : constant Files.Commands.Command_Id := Files.Commands.Refresh_Directory_Command;
         Sec_Key  : constant String := "shortcut." & Files.Commands.Identifier (Sec_Cmd);
         Sec_Text : constant String :=
           Files.Commands.Shortcut_Display_Text (Files.Commands.Secondary_Shortcut_For (Sec_Cmd));
         Found    : Boolean := False;
      begin
         Assert (Sec_Text /= "", "the sample command has a secondary shortcut");
         for F of Fields loop
            if To_String (F.Key) = Sec_Key then
               Found := True;
               Assert (Ada.Strings.Fixed.Index (To_String (F.Help), Sec_Text) > 0,
                       "the row help surfaces the built-in secondary shortcut");
            end if;
         end loop;
         Assert (Found, "the command with a secondary has a shortcut row");
      end;
   end Test_Shortcut_Editing;
