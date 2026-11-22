with Files.Controller;
with Files.Controller.Testing;
with Files.Overlays.Settings_Form;
with Files.Model.Settings_Pane;
separate (Files_Suite.Settings)
   procedure Test_Settings_Form_Mapping_Navigation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      package SP renames Guikit.Settings_Panel;

      Base  : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Draft : Files.Settings.Settings_Draft := Files.Settings.Make_Draft (Base);
      Model : Files.Model.Window_Model;
      Saved : Boolean;
      --  What the test's saves have saved, as the app's settings would be.
      Live  : Files.Settings.Settings_Model := Base;

      --  Save the pane's draft, as the app does when a change asks for it.
      procedure Save_Now is
         Result : constant Files.Controller.Controller_Result :=
           Files.Controller.Testing.Save_Settings
             (Model, Live, Join (Join (Root, "mapping-navigation"), "settings.conf"));
         pragma Unreferenced (Result);
      begin
         null;
      end Save_Now;

      function Changed_Value (Field, Value : String) return SP.Change is
        ((Kind  => SP.Value_Changed,
          Key   => To_Unbounded_String (Field),
          Value => To_Unbounded_String (Value)));

      function Button (Value : String) return SP.Change is
        ((Kind  => SP.Button_Pressed,
          Key   => To_Unbounded_String ("form.filetype.buttons"),
          Value => To_Unbounded_String (Value)));

      function Ext return String is
        (To_String (Files.Model.Settings_Pane.Draft_Of (Model).Filetype_Extension));

      function Count return Natural is
        (Natural (Files.Model.Settings_Pane.Draft_Of (Model).Filetype_Keys.Length));

      function Ext_Label return String is
         Fields : constant SP.Field_Vectors.Vector :=
           Files.Overlays.Settings_Form.Fields (Files.Model.Settings_Pane.Draft_Of (Model));
      begin
         for F of Fields loop
            if To_String (F.Key) = "settings.filetype_extension" then
               return To_String (F.Label);
            end if;
         end loop;
         return "";
      end Ext_Label;
   begin
      Draft.Filetype_Keys.Clear;
      Draft.Filetype_Values.Clear;
      Draft.Filetype_Keys.Append (To_Unbounded_String ("txt"));
      Draft.Filetype_Values.Append (To_Unbounded_String ("text/plain"));
      Draft.Filetype_Keys.Append (To_Unbounded_String ("md"));
      Draft.Filetype_Values.Append (To_Unbounded_String ("text/markdown"));
      Draft.Filetype_Index := 1;
      --  The pane opens on these rows as saved, with the keymap they hold
      --  (no overrides another test may have left).
      Files.Commands.Reset_Shortcut_Overrides;
      Files.Settings.Normalize_Draft (Draft);
      Live := Files.Settings.Apply_Draft (Base, Draft).Settings;
      Files.Overlays.Settings_Form.Begin_Edit (Model, Live);
      Files.Overlays.Settings_Form.Set_Draft (Model, Draft);

      Files_Suite.Support.Assert_Equal

        (Ext,

         "txt",

         "the first mapping entry is selected");
      Assert (Ada.Strings.Fixed.Index (Ext_Label, "(1/2)") > 0, "the key field label shows the entry counter");

      Saved := Files.Overlays.Settings_Form.Apply_Change (Model, Button ("next"));
      Assert (not Saved, "paging to the next entry does not save");
      Files_Suite.Support.Assert_Equal (Ext, "md", "Next selects the second entry");
      Assert (Ada.Strings.Fixed.Index (Ext_Label, "(2/2)") > 0, "the counter follows the selection");

      Saved := Files.Overlays.Settings_Form.Apply_Change (Model, Button ("next"));
      Files_Suite.Support.Assert_Equal (Ext, "txt", "Next wraps to the first entry");
      Saved := Files.Overlays.Settings_Form.Apply_Change (Model, Button ("prev"));
      Files_Suite.Support.Assert_Equal (Ext, "md", "Prev wraps back to the last entry");

      Saved := Files.Overlays.Settings_Form.Apply_Change (Model, Button ("add"));
      Assert (not Saved, "adding a blank entry, which the file does not hold, does not save");
      Files_Suite.Support.Assert_Equal (Count, 3, "Add appends a mapping entry");
      Assert
        (Files.Settings.Apply_Draft
           (Files.Settings.Default_Settings, Files.Model.Settings_Pane.Draft_Of (Model)).Success,
         "a freshly added, still blank row does not block saving other settings");

      --  A save keeps the pane on the new, blank row (the file does not
      --  hold it), rather than rebuilding every group, and keeps the rows
      --  in the order the pane showed them.
      Save_Now;
      Files_Suite.Support.Assert_Equal (Count, 3, "a save keeps the row just added");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Settings_Pane.Draft_Of (Model).Filetype_Index, 3, "a save keeps the group on its entry");
      Files_Suite.Support.Assert_Equal
        (To_String (Files.Model.Settings_Pane.Draft_Of (Model).Filetype_Keys.Element (1)), "txt",
         "a save keeps the pane's order of rows");

      Saved := Files.Overlays.Settings_Form.Apply_Change (Model, Button ("remove"));
      Assert (not Saved, "removing the blank entry does not save");
      Files_Suite.Support.Assert_Equal (Count, 2, "Remove drops the blank entry");

      Saved := Files.Overlays.Settings_Form.Apply_Change (Model, Button ("remove"));
      Assert (Saved, "removing an entry the file holds saves");
      Files_Suite.Support.Assert_Equal (Count, 1, "Remove drops the mapping entry");
      Save_Now;

      --  A saved row blanked by typing, then removed, is a change the file
      --  must take: what counts is what it holds, not the draft before.
      Saved := Files.Overlays.Settings_Form.Apply_Change (Model, Changed_Value ("settings.filetype_extension", ""));
      Saved := Files.Overlays.Settings_Form.Apply_Change (Model, Changed_Value ("settings.filetype_value", ""));
      Saved := Files.Overlays.Settings_Form.Apply_Change (Model, Button ("remove"));
      Assert (Saved, "removing a saved row blanked by typing saves");
      Files_Suite.Support.Assert_Equal (Count, 0, "every entry removed");
      Save_Now;
      Saved := Files.Overlays.Settings_Form.Apply_Change (Model, Button ("remove"));
      Assert (not Saved, "removing from an empty group changes nothing and does not save");

      --  Typing into the empty group starts its first entry, instead of an
      --  edit that names no row and is dropped.
      Saved := Files.Overlays.Settings_Form.Apply_Change (Model, Changed_Value ("settings.filetype_extension", "log"));
      Files_Suite.Support.Assert_Equal (Count, 1, "typing into an empty group starts an entry");
      Files_Suite.Support.Assert_Equal (Ext, "log", "the typed key is the new entry's");

      --  A save shows the rows as the file holds them: a second row typed
      --  with the first one's key in another form is merged into it, and
      --  the group stays on that entry.
      Saved := Files.Overlays.Settings_Form.Apply_Change
        (Model, Changed_Value ("settings.filetype_value", "text/plain"));
      Saved := Files.Overlays.Settings_Form.Apply_Change (Model, Button ("add"));
      Assert (Saved, "adding a row saves the row typed before it, which the file does not hold yet");
      Saved := Files.Overlays.Settings_Form.Apply_Change (Model, Changed_Value ("settings.filetype_extension", ".LOG"));
      Saved := Files.Overlays.Settings_Form.Apply_Change
        (Model, Changed_Value ("settings.filetype_value", "text/x-log"));
      Files_Suite.Support.Assert_Equal (Count, 2, "the second row is in the pane before the save");
      Save_Now;
      Files_Suite.Support.Assert_Equal (Count, 1, "after a save the pane holds the rows the file holds");
      Files_Suite.Support.Assert_Equal (Ext, "log", "the saved key is shown in its normal form");
      Files_Suite.Support.Assert_Equal
        (To_String (Files.Model.Settings_Pane.Draft_Of (Model).Filetype_Value), "text/x-log",
         "the merged row holds the value saved");

      --  Paging keeps an error the draft shows: the row it is about is
      --  still there.
      declare
         Shown : Files.Settings.Settings_Draft := Files.Model.Settings_Pane.Draft_Of (Model);
      begin
         Shown.Valid := False;
         Shown.Error_Key := To_Unbounded_String ("settings.invalid");
         Files.Overlays.Settings_Form.Set_Draft (Model, Shown);
         Saved := Files.Overlays.Settings_Form.Apply_Change (Model, Button ("next"));
         Assert (not Files.Model.Settings_Pane.Draft_Of (Model).Valid, "paging keeps the draft's error");
      end;

      --  A re-check that finds the draft valid, with nothing to save, clears
      --  the error line an earlier check left there.
      Files.Model.Set_Error (Model, "error.settings.invalid_mapping");
      Saved := Files.Overlays.Settings_Form.Apply_Change (Model, Button ("add"));
      Assert (not Saved, "adding a blank row to a valid draft saves nothing");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model), "", "a valid re-check clears the error line");

      --  A shortcut rebound but not saved (its save refused, say) is part of
      --  what a later change weighs: the next re-check saves it.
      Files.Commands.Reset_Shortcut_Overrides;
      Save_Now;
      Saved := Files.Overlays.Settings_Form.Apply_Change (Model, Changed_Value
           ("shortcut.view.small",
            Files.Commands.Shortcut_Text (Files.Commands.Parse_Shortcut ("control+shift+5"))));
      Saved := Files.Overlays.Settings_Form.Apply_Change (Model, Button ("remove"));
      Assert (Saved, "a change after an unsaved rebind saves the rebind");
      Files.Commands.Reset_Shortcut_Overrides;

      --  Reset with nothing to reset does not save, however the pane was left
      --  (an entry paged to, an error shown); with a saved shortcut override
      --  it does, to drop it.
      declare
         Defaults : Files.Settings.Settings_Draft := Files.Settings.Make_Draft (Files.Settings.Default_Settings);
         With_Override : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Reset_Button  : constant SP.Change :=
           (Kind  => SP.Button_Pressed,
            Key   => To_Unbounded_String ("form.actions"),
            Value => To_Unbounded_String ("reset"));
      begin
         Defaults.Valid := False;
         Defaults.Error_Key := To_Unbounded_String ("settings.invalid");
         Files.Overlays.Settings_Form.Begin_Edit (Model, Files.Settings.Default_Settings);
         Files.Overlays.Settings_Form.Set_Draft (Model, Defaults);
         Saved := Files.Overlays.Settings_Form.Apply_Change (Model, Reset_Button);
         Assert (not Saved, "a reset that changes nothing does not save");

         Files.Commands.Set_Shortcut_Override
           (Files.Commands.Select_Small_Icons_Command, Files.Commands.Parse_Shortcut ("control+shift+5"));
         Files.Overlays.Settings_Form.Store_Shortcut_Overrides (With_Override);
         Files.Overlays.Settings_Form.Begin_Edit (Model, With_Override);
         Files.Overlays.Settings_Form.Set_Draft (Model, Defaults);
         Saved := Files.Overlays.Settings_Form.Apply_Change (Model, Reset_Button);
         Assert (Saved, "a reset saves to drop a saved shortcut override");
         Files.Commands.Reset_Shortcut_Overrides;
      end;
   end Test_Settings_Form_Mapping_Navigation;
