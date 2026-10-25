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
        (To_String (Files.Model.Settings_Draft_Of (Model).Filetype_Extension));

      function Count return Natural is
        (Natural (Files.Model.Settings_Draft_Of (Model).Filetype_Keys.Length));

      function Ext_Label return String is
         Fields : constant SP.Field_Vectors.Vector := Files.Settings_Form.Fields (Model);
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
      Files.Model.Begin_Settings_Edit (Model, Draft);

      Files_Suite.Support.Assert_Equal

        (Ext,

         "txt",

         "the first mapping entry is selected");
      Assert (Ada.Strings.Fixed.Index (Ext_Label, "(1/2)") > 0, "the key field label shows the entry counter");

      Saved := Files.Settings_Form.Apply (Model, Button ("next"));
      Assert (not Saved, "paging to the next entry does not save");
      Files_Suite.Support.Assert_Equal (Ext, "md", "Next selects the second entry");
      Assert (Ada.Strings.Fixed.Index (Ext_Label, "(2/2)") > 0, "the counter follows the selection");

      Saved := Files.Settings_Form.Apply (Model, Button ("next"));
      Files_Suite.Support.Assert_Equal (Ext, "txt", "Next wraps to the first entry");
      Saved := Files.Settings_Form.Apply (Model, Button ("prev"));
      Files_Suite.Support.Assert_Equal (Ext, "md", "Prev wraps back to the last entry");

      Saved := Files.Settings_Form.Apply (Model, Button ("add"));
      Assert (Saved, "adding an entry saves");
      Files_Suite.Support.Assert_Equal (Count, 3, "Add appends a mapping entry");
      Assert
        (Files.Settings.Apply_Draft
           (Files.Settings.Default_Settings, Files.Model.Settings_Draft_Of (Model)).Success,
         "a freshly added, still blank row does not block saving other settings");

      Saved := Files.Settings_Form.Apply (Model, Button ("remove"));
      Assert (Saved, "removing an entry saves");
      Files_Suite.Support.Assert_Equal (Count, 2, "Remove drops the mapping entry");
   end Test_Settings_Form_Mapping_Navigation;
