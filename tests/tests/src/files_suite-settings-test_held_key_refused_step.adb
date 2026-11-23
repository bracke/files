with Files.Settings.Testing;
with Files.Settings.Storage;
with Files.Controller;
with Files.Interaction;
with Files.Overlays.Settings_Form;
with Files.Settings.Path_References;
separate (Files_Suite.Settings)
   --  A held arrow's step the settings file could not hold is refused as
   --  any other settings change is: the error line says why, the settings
   --  in force stay as they were and the pane shows them again. Letting go
   --  writes every step that was accepted.
   procedure Test_Held_Key_Refused_Step (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Path   : constant String := Join (Root, "held-full.conf");
      Result : Files.Interaction.Interaction_Result;

      function Length_Of (Settings : Files.Settings.Settings_Model) return Natural is
        (Files.Settings.To_Text (Settings)'Length);

      --  Open the pane on Settings and focus its Nth field.
      function Focus_Field
        (Model    : in out Files.Model.Window_Model;
         Settings : Files.Settings.Settings_Model;
         Nth      : Positive) return Boolean
      is
         Seen : Natural := 0;
         Keys : Ada.Strings.Unbounded.Unbounded_String;
      begin
         Files.Overlays.Settings_Form.Begin_Edit (Model, Settings);
         for Section in 1 .. Files.Model.Settings_Pane.Section_Count (Model) loop
            Files.Model.Settings_Pane.Set_Active_Section (Model, Section);
            for Step in 1 .. 200 loop
               --  Each field once, however often the focus passes it.
               if Ada.Strings.Unbounded.Index
                   (Keys, "|" & Files.Model.Settings_Pane.Focused_Key (Model) & "|") = 0
               then
                  Ada.Strings.Unbounded.Append (Keys, "|" & Files.Model.Settings_Pane.Focused_Key (Model) & "|");
                  Seen := Seen + 1;
                  if Seen = Nth then
                     return True;
                  end if;
               end if;
               Files.Model.Settings_Pane.Move_Focus (Model, 1);
            end loop;
         end loop;
         return False;
      end Focus_Field;

      --  Open the pane on Settings and focus the field of Key.
      function Focus_Key
        (Model    : in out Files.Model.Window_Model;
         Settings : Files.Settings.Settings_Model;
         Key      : String) return Boolean is
      begin
         Files.Overlays.Settings_Form.Begin_Edit (Model, Settings);
         for Section in 1 .. Files.Model.Settings_Pane.Section_Count (Model) loop
            Files.Model.Settings_Pane.Set_Active_Section (Model, Section);
            for Step in 1 .. 200 loop
               if Files.Model.Settings_Pane.Focused_Key (Model) = Key then
                  return True;
               end if;
               Files.Model.Settings_Pane.Move_Focus (Model, 1);
            end loop;
         end loop;
         return False;
      end Focus_Key;

      procedure Held
        (Model    : in out Files.Model.Window_Model;
         Settings : in out Files.Settings.Settings_Model;
         Key      : Guikit.Input.Key_Code) is
      begin
         Files.Model.Settings_Pane.Note_Key_Repeat (Model, True);
         Files.Interaction.Handle_Key (Model, Settings, Path, Key, Result => Result);
         Files.Model.Settings_Pane.Note_Key_Repeat (Model, False);
      end Held;

      Base   : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Field  : Natural := 0;
      Steps  : Natural := 0;
      Growth : Natural := 0;
   begin
      Reset_Root;
      --  A field whose held arrow lengthens the settings text (a number
      --  gaining a digit, a choice with a longer name): which one, how many
      --  steps from where held Left leaves it and by how many bytes, tried
      --  on copies.
      for Nth in 1 .. 100 loop
         declare
            Model    : Files.Model.Window_Model := Files_Suite.Support.Models.Sample_Model;
            Lowest   : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
            Probe    : Files.Settings.Settings_Model;
         begin
            exit when not Focus_Field (Model, Lowest, Nth);
            for Step in 1 .. 40 loop
               Held (Model, Lowest, Guikit.Input.Key_Left);
            end loop;
            Probe := Lowest;
            Steps := 0;
            while Steps < 40 and then Length_Of (Probe) <= Length_Of (Lowest) loop
               Held (Model, Probe, Guikit.Input.Key_Right);
               Steps := Steps + 1;
            end loop;
            if Length_Of (Probe) > Length_Of (Lowest) then
               Field := Nth;
               Growth := Length_Of (Probe) - Length_Of (Lowest);
               Base := Lowest;
               exit;
            end if;
         end;
      end loop;
      Assert (Field > 0, "a field's held arrow lengthens the settings text");
      --  Pad the settings with favorites until that step would cross the
      --  file's bound by one byte.
      declare
         Target : constant Natural := Files.Settings.Testing.Max_Text_Bytes - Growth + 1;
         Index  : Natural := 0;

         procedure Add (Length : Positive) is
            Name : constant String := "/pad" & Integer'Image (Index) & "/";
         begin
            Index := Index + 1;
            Files.Settings.Path_References.Toggle_Favorite_Path
              (Base, Name & Ada.Strings.Fixed."*" (Integer'Max (1, Length - Name'Length), 'p'));
         end Add;
      begin
         while Target - Length_Of (Base) > 50_000 loop
            Add (40_000);
         end loop;
         declare
            Before : constant Natural := Length_Of (Base);
            Rest   : constant Natural := Target - Before;
            Kept   : constant Files.Settings.Settings_Model := Base;
            Saved  : constant Natural := Index;
            Probe  : Files.Settings.Settings_Model;
         begin
            --  One favorite of Rest bytes; its line's overhead is measured
            --  on a trial, then the line is made that much shorter.
            Add (Rest);
            Probe := Base;
            Base := Kept;
            Index := Saved;
            Add (Rest - (Length_Of (Probe) - Before - Rest));
         end;
         Files_Suite.Support.Assert_Equal (Length_Of (Base), Target, "the settings are padded to the bound");
         Assert (Files.Settings.Testing.Loadable (Base), "the padded settings still load");
      end;
      declare
         Model    : Files.Model.Window_Model := Files_Suite.Support.Models.Sample_Model;
         Settings : Files.Settings.Settings_Model := Base;
         Kept     : Files.Settings.Settings_Model;
         Shown    : Ada.Strings.Unbounded.Unbounded_String;
      begin
         --  A held step the file can hold (the font size, whose step keeps
         --  the text's length): in force, and waiting to be written.
         declare
            --  The pane names a field by its form key, not the file's.
            Font_Key : constant String := "settings.font_pixel_size";
            Before   : constant Files.Settings.Settings_Model := Settings;
         begin
            Assert (Focus_Key (Model, Settings, Font_Key), "the font size field is found");
            Held (Model, Settings, Guikit.Input.Key_Right);
            Assert (not Files.Settings.Same_Content (Settings, Before), "the font size step is in force");
            Files_Suite.Support.Assert_Equal
              (Length_Of (Settings), Length_Of (Before), "the font size step keeps the text's length");
         end;
         Assert (Focus_Field (Model, Settings, Field), "the field is found again");
         for Step in 1 .. Steps - 1 loop
            Held (Model, Settings, Guikit.Input.Key_Right);
         end loop;
         Kept := Settings;
         Shown := Ada.Strings.Unbounded.To_Unbounded_String (Files.Model.Settings_Pane.Focused_Value (Model));
         Files.Model.Set_Error (Model, "");
         Held (Model, Settings, Guikit.Input.Key_Right);
         Assert (Files.Settings.Same_Content (Settings, Kept), "the step the file cannot hold is not in force");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Last_Error_Key (Model), "error.settings.full", "the error line says why");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Settings_Pane.Focused_Value (Model), Ada.Strings.Unbounded.To_String (Shown),
            "the pane goes back to the value in force");
         Assert (Files.Settings.Testing.Loadable (Settings), "the settings in force still load");
         Assert (not Ada.Directories.Exists (Path), "nothing is written while the key is held");

         --  The key is let go: the window takes the deferred save and
         --  writes what is in force.
         Assert (Files.Model.Settings_Pane.Take_Deferred_Save (Model), "the accepted steps wait to be written");
         Files.Controller.Persist_Held_Settings (Model, Settings, Path);
         declare
            Written : constant Files.Settings.Settings_Parse_Result := Files.Settings.Storage.Load_File (Path);
         begin
            Assert (Written.Success, "the written settings load");
            Assert (Files.Settings.Same_Content (Written.Settings, Kept), "the file holds every accepted step");
            Files_Suite.Support.Assert_Equal
              (Files.Model.Settings_Pane.Focused_Value (Model), Ada.Strings.Unbounded.To_String (Shown),
               "the pane shows the value in force, not the refused one");
         end;
      end;
   end Test_Held_Key_Refused_Step;
