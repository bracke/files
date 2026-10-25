separate (Files_Suite.Settings)
   --  Files.Settings_Form maps the draft to typed panel fields and applies the
   --  panel's emitted changes: paging (Prev/Next) moves the selected mapping
   --  entry without saving, Add/Remove edit the list and save, and the key
   --  field's label carries the "i/n" entry counter.
   --  The Shortcuts tab: the form emits one press-to-capture row per command
   --  carrying its current binding, and Apply routes a captured chord to the live
   --  Files.Commands keymap -- rebinding, rejecting a clash with another command,
   --  unbinding on an empty chord, and clearing the override when set to default.
   procedure Test_Shortcut_Editing (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  Clears the overrides this test sets, on an assertion failure too.
      Shortcuts : Files_Suite.Support.Shortcut_Guard;
      pragma Unreferenced (Shortcuts);
      package SP renames Guikit.Settings_Panel;
      use type SP.Field_Kind;

      Base  : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Draft : constant Files.Settings.Settings_Draft := Files.Settings.Make_Draft (Base);
      Model : Files.Model.Window_Model;
      Saved : Boolean;

      --  The capture flow always feeds Apply the canonical Shortcut_Text form
      --  (modifiers normalised to shift+control+alt+meta), so the test uses it too.
      New_Chord : constant String :=
        Files.Commands.Shortcut_Text (Files.Commands.Parse_Shortcut ("control+shift+5"));

      function Change (Key, Value : String) return SP.Change is
        ((Kind => SP.Value_Changed, Key => To_Unbounded_String (Key), Value => To_Unbounded_String (Value)));

      function Row_Value (Key : String) return String is
         Fields : constant SP.Field_Vectors.Vector := Files.Settings_Form.Fields (Model);
      begin
         for F of Fields loop
            if To_String (F.Key) = Key then
               return (if F.Kind = SP.Shortcut then To_String (F.Value) else "<not-a-shortcut>");
            end if;
         end loop;
         return "<absent>";
      end Row_Value;

      Small_Text : constant String :=
        Files.Commands.Shortcut_Text
          (Files.Commands.Default_Shortcut_For (Files.Commands.Select_Small_Icons_Command));
   begin
      Files.Commands.Reset_Shortcut_Overrides;
      Files.Model.Begin_Settings_Edit (Model, Draft);

      --  The form emits a row per command, keyed by "shortcut.<identifier>",
      --  showing the command's current shortcut.
      Files_Suite.Support.Assert_Equal
        (Row_Value ("shortcut.view.small"),
         Small_Text,
         "the shortcut row shows the command's current binding");

      --  Rebind Small Icons to a fresh chord (a key added by the expansion).
      Saved := Files.Settings_Form.Apply (Model, Change ("shortcut.view.small", New_Chord));
      Assert (Saved, "rebinding a shortcut saves");
      declare
         SC : constant Files.Commands.Shortcut :=
           Files.Commands.Shortcut_For (Files.Commands.Select_Small_Icons_Command);
         Is_Set : Boolean;
         Ignore : constant Files.Commands.Shortcut :=
           Files.Commands.Shortcut_Override (Files.Commands.Select_Small_Icons_Command, Is_Set);
      begin
         pragma Unreferenced (Ignore);
         Assert (SC.Present, "the live keymap reflects the rebind (present)");
         Files_Suite.Support.Assert_Equal (SC.Key, Guikit.Input.Key_5, "the live keymap reflects the rebind (key)");
         Assert (SC.Modifiers (Guikit.Input.Control_Key), "the live keymap reflects the rebind (Control)");
         Assert (SC.Modifiers (Guikit.Input.Shift_Key), "the live keymap reflects the rebind (Shift)");
         Assert (Is_Set, "the rebind is recorded as an override");
         Files_Suite.Support.Assert_Equal
           (Row_Value ("shortcut.view.small"),
            New_Chord,
            "the row now shows the new chord");
      end;

      --  Binding the same chord to a different command is rejected as a conflict.
      Saved := Files.Settings_Form.Apply (Model, Change ("shortcut.view.large", New_Chord));
      Assert (not Saved, "a conflicting rebind does not save");
      Assert (Files.Commands.Find_By_Shortcut
                (Guikit.Input.Key_5,
                 [Guikit.Input.Control_Key => True, Guikit.Input.Shift_Key => True, others => False])
              = Files.Commands.Select_Small_Icons_Command,
              "the chord still resolves to its original command after a rejected clash");

      --  An empty chord unbinds the command.
      Saved := Files.Settings_Form.Apply (Model, Change ("shortcut.view.small", ""));
      Assert (Saved, "unbinding saves");
      Assert (not Files.Commands.Shortcut_For (Files.Commands.Select_Small_Icons_Command).Present,
              "the command has no shortcut after an empty-chord unbind");

      --  Setting a command back to its built-in default clears the override.
      Saved := Files.Settings_Form.Apply (Model, Change ("shortcut.view.small", Small_Text));
      Assert (Saved, "restoring the default saves");
      declare
         Is_Set : Boolean;
         Ignore : constant Files.Commands.Shortcut :=
           Files.Commands.Shortcut_Override (Files.Commands.Select_Small_Icons_Command, Is_Set);
      begin
         pragma Unreferenced (Ignore);
         Assert (not Is_Set, "binding a command to its default clears the override");
      end;

      --  The pane's Reset button is a full reset: it clears shortcut overrides
      --  too, not just the draft values.
      Files.Commands.Set_Shortcut_Override
        (Files.Commands.Select_Small_Icons_Command, Files.Commands.Parse_Shortcut ("control+shift+5"));
      Saved := Files.Settings_Form.Apply
        (Model,
         (Kind  => SP.Button_Pressed,
          Key   => To_Unbounded_String ("form.actions"),
          Value => To_Unbounded_String ("reset")));
      Assert (Saved, "the reset button saves");
      declare
         Is_Set : Boolean;
         Ignore : constant Files.Commands.Shortcut :=
           Files.Commands.Shortcut_Override (Files.Commands.Select_Small_Icons_Command, Is_Set);
      begin
         pragma Unreferenced (Ignore);
         Assert (not Is_Set, "Reset clears shortcut overrides, returning the keymap to defaults");
      end;

      --  A command with a built-in secondary shortcut surfaces it (read-only) in
      --  its row help, so an "already used" rejection is explicable.
      declare
         Fields   : constant SP.Field_Vectors.Vector := Files.Settings_Form.Fields (Model);
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
