with Files.Controller;
with Files.Controller.Testing;
with Files.Settings_Form;
with Files.Model.Settings_Pane;
separate (Files_Suite.Settings)
   procedure Test_Settings_Form_Mapping_Navigation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      package SP renames Guikit.Settings_Panel;

      Base  : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Draft : Files.Settings.Settings_Draft := Files.Settings.Make_Draft (Base);
      Model : Files.Model.Window_Model;
      Saved : Boolean;

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
           Files.Settings_Form.Fields (Files.Model.Settings_Pane.Draft_Of (Model));
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
      Files.Settings_Form.Begin_Edit (Model, Draft);

      Files_Suite.Support.Assert_Equal

        (Ext,

         "txt",

         "the first mapping entry is selected");
      Assert (Ada.Strings.Fixed.Index (Ext_Label, "(1/2)") > 0, "the key field label shows the entry counter");

      Saved := Files.Settings_Form.Apply_Change (Model, Button ("next"));
      Assert (not Saved, "paging to the next entry does not save");
      Files_Suite.Support.Assert_Equal (Ext, "md", "Next selects the second entry");
      Assert (Ada.Strings.Fixed.Index (Ext_Label, "(2/2)") > 0, "the counter follows the selection");

      Saved := Files.Settings_Form.Apply_Change (Model, Button ("next"));
      Files_Suite.Support.Assert_Equal (Ext, "txt", "Next wraps to the first entry");
      Saved := Files.Settings_Form.Apply_Change (Model, Button ("prev"));
      Files_Suite.Support.Assert_Equal (Ext, "md", "Prev wraps back to the last entry");

      Saved := Files.Settings_Form.Apply_Change (Model, Button ("add"));
      Assert (not Saved, "adding a blank entry, which the file does not hold, does not save");
      Files_Suite.Support.Assert_Equal (Count, 3, "Add appends a mapping entry");
      Assert
        (Files.Settings.Apply_Draft
           (Files.Settings.Default_Settings, Files.Model.Settings_Pane.Draft_Of (Model)).Success,
         "a freshly added, still blank row does not block saving other settings");

      --  The save that follows the add keeps the pane on the new, blank row
      --  (the file does not hold it), rather than rebuilding every group.
      declare
         Settings : Files.Settings.Settings_Model := Base;
         Result   : constant Files.Controller.Controller_Result :=
           Files.Controller.Testing.Save_Settings
             (Model, Settings, Join (Join (Root, "mapping-navigation"), "settings.conf"));
         pragma Unreferenced (Result);
      begin
         Files_Suite.Support.Assert_Equal (Count, 3, "a save keeps the row just added");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Settings_Pane.Draft_Of (Model).Filetype_Index, 3, "a save keeps the group on its entry");
      end;

      Saved := Files.Settings_Form.Apply_Change (Model, Button ("remove"));
      Assert (not Saved, "removing the blank entry does not save");
      Files_Suite.Support.Assert_Equal (Count, 2, "Remove drops the blank entry");

      Saved := Files.Settings_Form.Apply_Change (Model, Button ("remove"));
      Assert (Saved, "removing an entry the file holds saves");
      Files_Suite.Support.Assert_Equal (Count, 1, "Remove drops the mapping entry");
      Saved := Files.Settings_Form.Apply_Change (Model, Button ("remove"));
      Files_Suite.Support.Assert_Equal (Count, 0, "every entry removed");
      Saved := Files.Settings_Form.Apply_Change (Model, Button ("remove"));
      Assert (not Saved, "removing from an empty group changes nothing and does not save");

      --  Typing into the empty group starts its first entry, instead of an
      --  edit that names no row and is dropped.
      Saved := Files.Settings_Form.Apply_Change
        (Model,
         (Kind  => SP.Value_Changed,
          Key   => To_Unbounded_String ("settings.filetype_extension"),
          Value => To_Unbounded_String ("log")));
      Files_Suite.Support.Assert_Equal (Count, 1, "typing into an empty group starts an entry");
      Files_Suite.Support.Assert_Equal (Ext, "log", "the typed key is the new entry's");

      --  A save shows the rows as the file holds them: a second row typed
      --  with the first one's key in another form is merged into it, and
      --  the group stays on that entry.
      Saved := Files.Settings_Form.Apply_Change
        (Model,
         (Kind  => SP.Value_Changed,
          Key   => To_Unbounded_String ("settings.filetype_value"),
          Value => To_Unbounded_String ("text/plain")));
      Saved := Files.Settings_Form.Apply_Change (Model, Button ("add"));
      Saved := Files.Settings_Form.Apply_Change
        (Model,
         (Kind  => SP.Value_Changed,
          Key   => To_Unbounded_String ("settings.filetype_extension"),
          Value => To_Unbounded_String (".LOG")));
      Saved := Files.Settings_Form.Apply_Change
        (Model,
         (Kind  => SP.Value_Changed,
          Key   => To_Unbounded_String ("settings.filetype_value"),
          Value => To_Unbounded_String ("text/x-log")));
      Files_Suite.Support.Assert_Equal (Count, 2, "the second row is in the pane before the save");
      declare
         Settings : Files.Settings.Settings_Model := Base;
         Result   : constant Files.Controller.Controller_Result :=
           Files.Controller.Testing.Save_Settings
             (Model, Settings, Join (Join (Root, "mapping-navigation"), "settings.conf"));
         pragma Unreferenced (Result);
      begin
         Files_Suite.Support.Assert_Equal (Count, 1, "after a save the pane holds the rows the file holds");
         Files_Suite.Support.Assert_Equal (Ext, "log", "the saved key is shown in its normal form");
         Files_Suite.Support.Assert_Equal
           (To_String (Files.Model.Settings_Pane.Draft_Of (Model).Filetype_Value), "text/x-log",
            "the merged row holds the value saved");
      end;

      --  Reset with nothing to reset does not save, however the pane was left
      --  (an entry paged to, an error shown); with shortcut overrides it does.
      declare
         Defaults : Files.Settings.Settings_Draft := Files.Settings.Make_Draft (Files.Settings.Default_Settings);
         Had_Overrides : constant Boolean := Files.Commands.Has_Shortcut_Overrides;
      begin
         Defaults.Valid := False;
         Defaults.Error_Key := To_Unbounded_String ("settings.invalid");
         Files.Settings_Form.Begin_Edit (Model, Defaults);
         Saved := Files.Settings_Form.Apply_Change
           (Model,
            (Kind  => SP.Button_Pressed,
             Key   => To_Unbounded_String ("form.actions"),
             Value => To_Unbounded_String ("reset")));
         Assert (Saved = Had_Overrides, "a reset that changes nothing saves only to drop shortcut overrides");
      end;
   end Test_Settings_Form_Mapping_Navigation;
